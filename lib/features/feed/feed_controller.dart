import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_error.dart';
import '../../core/files/external_opener.dart';
import '../../core/files/file_transfer_service.dart';
import '../../core/files/media_picker.dart';
import '../../core/share/outgoing_share.dart';
import '../../core/utils/clock.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import '../../domain/transfer_progress.dart';
import 'attachment_previews.dart';
import 'selection_exporter.dart';

/// Состояние ленты одной базы: загрузка, периодический опрос облака,
/// отправка, удаление постов и сохранение файлов.
class FeedController extends ChangeNotifier {
  FeedController(
    this._repository, {
    required this._files,
    required this._pollInterval,
    this._media = const NoMediaPicker(),
    this._opener = const NoExternalOpener(),
    this._share = const DisabledShareSender(),
    this._clock = DateTime.now,
    ExportTexts exportTexts = ExportTexts.english,
  }) : _exporter = SelectionExporter(_repository, exportTexts) {
    // Повторный вход в ленту: записи уже известны — показываем их сразу,
    // обновление идёт в фоне.
    final cached = _repository.cachedPosts;
    if (cached != null) {
      _posts = cached;
      _initialLoad = false;
    }
  }

  final PostRepository _repository;
  final FileTransferService _files;
  final MediaPicker _media;
  final ExternalOpener _opener;
  final ShareSender _share;
  final Duration _pollInterval;
  final Clock _clock;
  final SelectionExporter _exporter;
  Timer? _timer;
  bool _refreshing = false;
  bool _disposed = false;

  List<Post> _posts = const [];
  bool _initialLoad = true;
  bool _sending = false;
  bool _bulkBusy = false;
  final Set<String> _saving = {};
  final Map<String, TransferProgress> _transfers = {};
  final Set<String> _cancelledTransfers = {};
  final Set<String> _selected = {};
  Object? _error;

  List<Post> get posts => _posts;
  bool get isInitialLoad => _initialLoad;
  bool get isSending => _sending;

  /// Последняя ошибка; текст на языке интерфейса — `describeError`.
  Object? get error => _error;

  /// Идёт ли сейчас скачивание файла из этого поста.
  bool isSaving(Post post) => _saving.contains(post.id);

  /// Прогресс передачи файла для этого поста (`null`, если передача не идёт).
  TransferProgress? transferProgress(Post post) => _transfers[post.id];

  /// Проверяет, была ли отменена передача.
  bool isTransferCancelled(String id) => _cancelledTransfers.contains(id);

  /// Отменяет передачу конкретного файла или папки.
  void cancelTransfer(String id) {
    _cancelledTransfers.add(id);
    _transfers.remove(id);
    _posts = _posts.where((p) => p.id != id).toList();
    _sending = _transfers.isNotEmpty;
    _notify();
  }

  /// Отменяет текущую отправку.
  void cancelActiveSend() {
    for (final id in _transfers.keys.toList()) {
      _cancelledTransfers.add(id);
    }
    _transfers.clear();
    _posts = _posts.where((p) => !p.id.startsWith('pending_')).toList();
    _sending = false;
    _notify();
  }

  // ---- Выделение нескольких постов ----

  bool get isSelecting => _selected.isNotEmpty;
  int get selectedCount => _selected.length;

  /// Идёт групповое скачивание или удаление.
  bool get isBulkBusy => _bulkBusy;

  bool isSelected(Post post) => _selected.contains(post.id);

  void toggleSelection(Post post) {
    if (!_selected.remove(post.id)) _selected.add(post.id);
    _notify();
  }

  void selectAll() {
    _selected.addAll(_posts.map((p) => p.id));
    _notify();
  }

  void clearSelection() {
    _selected.clear();
    _notify();
  }

  List<Post> get _selectedPosts =>
      _posts.where((p) => _selected.contains(p.id)).toList();

  /// Сохраняет выбранное одним файлом (см. [SelectionExporter]).
  /// Возвращает `true`, если файл сохранён; после этого выделение снимается.
  Future<bool> saveSelected() => _runBulk(() async {
    final exported = await _exporter.export(_selectedPosts, now: _clock());
    final saved = await _files.saveFile(
      fileName: exported.fileName,
      bytes: exported.bytes,
      mimeType: exported.mimeType,
    );
    if (saved) _selected.clear();
    return saved;
  });

  /// Удаляет выбранные посты на всех устройствах. Возвращает число удалённых.
  Future<int> deleteSelected() async {
    var deleted = 0;
    await _runBulk(() async {
      for (final post in _selectedPosts) {
        await _repository.deletePost(post);
        _posts = _posts.where((p) => p.id != post.id).toList();
        _selected.remove(post.id);
        deleted++;
        _notify();
      }
      return true;
    });
    return deleted;
  }

  // ---- «Поделиться» в другие приложения ----

  bool get canShare => _share.isAvailable;

  /// Содержимое вложений для превью и просмотра фото (с кешем в памяти).
  late final AttachmentPreviews previews = AttachmentPreviews(
    _repository.downloadAttachment,
  );

  /// Публичная доска у читателя: без отправки, комментариев и удаления.
  bool get isReadOnly => _repository.isReadOnly;

  /// Лимит размера файла в этой базе.
  int get maxFileSize => _repository.maxFileSize;

  /// Открывает системное меню «Поделиться» для одного поста.
  Future<void> sharePost(Post post) async {
    if (_saving.contains(post.id)) return;
    _saving.add(post.id);
    _notify();
    try {
      await _shareMany([post]);
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _saving.remove(post.id);
      _notify();
    }
  }

  /// Делится выбранными постами разом: тексты одним сообщением, файлы
  /// вложениями. После этого выделение снимается.
  Future<bool> shareSelected() => _runBulk(() async {
    await _shareMany(_selectedPosts);
    _selected.clear();
    return true;
  });

  Future<void> _shareMany(List<Post> posts) async {
    final ordered = [...posts]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final text = ordered
        .map((p) => p.text)
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    final files = <OutgoingFile>[
      for (final post in ordered) ...[
        if (post.attachment case final attachment?)
          OutgoingFile(
            name: attachment.fileName,
            bytes: await _repository.downloadAttachment(attachment),
            mimeType: attachment.mimeType,
          ),
        if (post.folder case final folder?)
          for (final entry in folder.files)
            OutgoingFile(
              name: entry.fileName,
              bytes: await _repository.downloadAttachment(entry.toAttachment()),
              mimeType: entry.mimeType,
            ),
      ],
    ];
    await _share.share(text: text, files: files);
  }

  Future<bool> _runBulk(Future<bool> Function() action) async {
    if (_bulkBusy || _selected.isEmpty) return false;
    _bulkBusy = true;
    _error = null;
    _notify();
    try {
      return await action();
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _bulkBusy = false;
      _notify();
    }
  }

  void start() {
    _firstLoad();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  /// Сначала — записи, сохранённые на устройстве (лента появляется сразу,
  /// даже без сети), затем обновление из облака.
  Future<void> _firstLoad() async {
    if (_initialLoad) {
      try {
        await _repository.warmUp();
      } catch (e) {
        debugPrint('Local cache unavailable: $e');
      }
      final cached = _repository.cachedPosts;
      if (cached != null && _initialLoad) {
        _posts = cached;
        _initialLoad = false;
        _notify();
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final remote = await _repository.fetchPosts();
      // Посты, удалённые на других устройствах, больше нельзя выбрать.
      final ids = remote.map((p) => p.id).toSet();
      _selected.retainWhere(ids.contains);
      // Например, не удалось обновить публичную доску: лента работает,
      // но владелец должен об этом знать.
      _error = _repository.backgroundError;

      // Сохраняем локальные временные записи, которые ещё загружаются.
      // Важно не удалять их по совпадению имени файла или папки с уже
      // существующими в ленте старыми постами, иначе при повторной отправке
      // папки или файла с тем же именем карточка загрузки пропадёт из ленты.
      final pending = _posts.where((p) => p.id.startsWith('pending_')).toList();
      final activePending = pending.where((p) {
        return _transfers.containsKey(p.id) && !_cancelledTransfers.contains(p.id);
      }).toList();

      _posts = [...remote, ...activePending];
    } catch (e) {
      _error = e;
      // Владелец закрыл доску: старые записи не показываем — их файлы уже
      // не открыть. При других ошибках (нет сети) лента остаётся.
      if (e is CodedError && e.code == ErrorCode.boardClosed) {
        _posts = const [];
        _selected.clear();
      }
    } finally {
      _refreshing = false;
      _initialLoad = false;
      _notify();
    }
  }

  /// Возвращает `true`, если сообщение отправлено.
  Future<bool> sendText(String text) =>
      _runSend(() => _repository.sendText(text));

  /// Предлагает выбрать один или несколько файлов и отправляет их по очереди
  /// (подпись [caption] прикрепляется к первому отправленному файлу).
  /// Возвращает `true`, если отправлен хотя бы один файл (`false` — отмена или ошибка).
  Future<bool> attachFile({String caption = ''}) => _attach(
    () => _files.pickFiles(maxSize: _repository.maxFileSize),
    caption: caption,
  );

  /// Предлагает выбрать папку на устройстве и отправляет её как единый пост
  /// со структурой файлов.
  Future<bool> attachFolder({String caption = ''}) async {
    if (_sending) return false;
    final PickedFolder? folder;
    try {
      folder = await _files.pickFolder(maxSize: _repository.maxFileSize);
    } catch (e) {
      _error = e;
      _notify();
      return false;
    }
    if (folder == null || folder.files.isEmpty) return false;
    return sendFolder(folder, caption: caption);
  }

  /// Отправляет папку со всеми файлами.
  Future<bool> sendFolder(PickedFolder folder, {String caption = ''}) async {
    final tempId =
        'pending_${_clock().millisecondsSinceEpoch}_folder_${folder.name}';
    final entries = [
      for (var i = 0; i < folder.files.length; i++)
        FolderEntry(
          id: 'pending_entry_${i}_${folder.files[i].name}',
          relativePath: folder.files[i].pathInFolder,
          size: folder.files[i].size,
          mimeType: folder.files[i].mimeType,
        ),
    ];
    final folderAttachment = FolderAttachment(
      name: folder.name,
      files: entries,
    );
    final pendingPost = Post(
      id: tempId,
      kind: PostKind.folder,
      createdAt: _clock(),
      senderDevice: '',
      text: caption.trim(),
      folder: folderAttachment,
    );
    _posts = [..._posts, pendingPost];
    _sending = true;
    _transfers[tempId] = TransferProgress(
      transferred: 0,
      total: folder.totalSize,
      bytesPerSecond: 0,
    );
    _notify();

    try {
      final tracker = TransferTracker(clock: _clock);
      _transfers[tempId] = tracker.update(0, folder.totalSize);
      _notify();

      final realPost = await _repository.sendFolder(
        folderName: folder.name,
        files: folder.files,
        caption: caption,
        onProgress: (count, total) {
          _transfers[tempId] = tracker.update(count, total);
          _notify();
        },
        isCancelled: () => isTransferCancelled(tempId),
      );
      final hasPending = _posts.any((p) => p.id == tempId);
      if (hasPending) {
        _posts = [for (final p in _posts) p.id == tempId ? realPost : p];
      } else {
        _posts = [..._posts.where((p) => p.id != realPost.id), realPost];
      }
      _transfers.remove(tempId);
      _error = null;
      _notify();
      return true;
    } catch (e) {
      _posts = _posts.where((p) => p.id != tempId).toList();
      _transfers.remove(tempId);
      if (e is! TransferCancelledException && !isTransferCancelled(tempId)) {
        _error = e;
      }
      _notify();
      return false;
    } finally {
      _cancelledTransfers.remove(tempId);
      _sending = _transfers.isNotEmpty;
      _notify();
    }
  }

  /// Можно ли выбрать фото или видео в Галерее (на телефоне).
  bool get canAttachMedia => _media.isAvailable;

  /// Можно ли открыть файл в другом приложении (на устройствах — да).
  bool get canOpenExternally => _opener.isAvailable;

  /// Открывает файл поста программой по умолчанию (или на выбор).
  Future<void> openExternally(Post post) async {
    final attachment = post.attachment;
    if (attachment == null || _saving.contains(post.id)) return;
    _saving.add(post.id);
    _notify();
    try {
      final cached = previews.peek(attachment);
      final Uint8List bytes;
      if (cached != null) {
        bytes = cached;
      } else {
        final tracker = TransferTracker(clock: _clock);
        _transfers[post.id] = tracker.update(0, attachment.size);
        _notify();
        bytes = await _repository.downloadAttachment(
          attachment,
          onProgress: (count, total) {
            _transfers[post.id] = tracker.update(count, total);
            _notify();
          },
        );
      }
      await _opener.open(
        fileName: attachment.fileName,
        bytes: bytes,
        mimeType: attachment.mimeType,
      );
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _saving.remove(post.id);
      _transfers.remove(post.id);
      _notify();
    }
  }

  /// Открытие отдельного вложения внешней программой.
  Future<void> openAttachmentExternally(Attachment attachment) async {
    try {
      final cached = previews.peek(attachment);
      final Uint8List bytes;
      if (cached != null) {
        bytes = cached;
      } else {
        bytes = await _repository.downloadAttachment(attachment);
      }
      await _opener.open(
        fileName: attachment.fileName,
        bytes: bytes,
        mimeType: attachment.mimeType,
      );
      _error = null;
    } catch (e) {
      _error = e;
      _notify();
    }
  }

  /// Скачивание байтов вложения (для вьюверов).
  Future<Uint8List> downloadAttachment(
    Attachment attachment, {
    ProgressCallback? onProgress,
  }) => _repository.downloadAttachment(attachment, onProgress: onProgress);

  /// Как [attachFile], но фото или видео выбираются в Галерее.
  Future<bool> attachMedia({String caption = ''}) => _attach(
    () => _media.pickMedia(maxSize: _repository.maxFileSize),
    caption: caption,
  );

  Future<bool> _attach(
    Future<List<PickedFile>> Function() pick, {
    required String caption,
  }) async {
    if (_sending) return false;
    final List<PickedFile> picked;
    try {
      picked = await pick();
    } catch (e) {
      _error = e;
      _notify();
      return false;
    }
    if (picked.isEmpty) return false;
    return await _sendPickedFiles(picked, caption: caption) > 0;
  }

  /// Отправляет файлы, перетащенные в окно, по очереди.
  /// Если перетащена папка, она отправляется как отдельный пост-папка.
  /// Все файлы сразу появляются на доске со статусом передачи.
  /// Возвращает, сколько файлов отправлено; ошибки попадают в [error].
  Future<int> sendDroppedFiles(List<XFile> files) async {
    if (files.isEmpty) return 0;

    // Если перетащена ровно одна папка
    if (files.length == 1 && files.first.path.isNotEmpty) {
      final folder = await _files.readDirectory(
        files.first.path,
        maxSize: _repository.maxFileSize,
      );
      if (folder != null && folder.files.isNotEmpty) {
        final ok = await sendFolder(folder);
        return ok ? 1 : 0;
      }
    }

    final queue = <({XFile file, String tempId, int size, bool isImage})>[];
    final pendingPosts = <Post>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final size = await file.length();
      final tempId =
          'pending_${_clock().millisecondsSinceEpoch}_${i}_${file.name}';
      final attachment = Attachment(
        id: tempId,
        fileName: file.name,
        size: size,
        mimeType: file.mimeType,
      );
      final post = Post(
        id: tempId,
        kind: PostKind.file,
        createdAt: _clock().add(Duration(milliseconds: i)),
        senderDevice: '',
        attachment: attachment,
      );
      queue.add((
        file: file,
        tempId: tempId,
        size: size,
        isImage: attachment.isImage,
      ));
      pendingPosts.add(post);
      _transfers[tempId] = TransferProgress(
        transferred: 0,
        total: size,
        bytesPerSecond: 0,
      );
    }

    _posts = [..._posts, ...pendingPosts];
    _sending = true;
    _notify();

    var sent = 0;
    Object? lastError;
    for (final item in queue) {
      final tempId = item.tempId;
      if (isTransferCancelled(tempId)) {
        _cancelledTransfers.remove(tempId);
        _transfers.remove(tempId);
        _posts = _posts.where((p) => p.id != tempId).toList();
        _notify();
        continue;
      }
      try {
        if (item.size > _repository.maxFileSize) {
          throw FileTooLargeException(item.size, _repository.maxFileSize);
        }
        final picked = await _files.readFile(
          item.file,
          maxSize: _repository.maxFileSize,
        );
        if (isTransferCancelled(tempId)) {
          _cancelledTransfers.remove(tempId);
          _transfers.remove(tempId);
          _posts = _posts.where((p) => p.id != tempId).toList();
          _notify();
          continue;
        }
        if (item.isImage &&
            picked.hasBytesInMemory &&
            picked.bytes.length <= attachmentPreviewAutoLimit) {
          previews.remember(tempId, picked.bytes);
        }
        final tracker = TransferTracker(clock: _clock);
        _transfers[tempId] = tracker.update(0, picked.size);
        _notify();

        final realPost = picked.hasBytesInMemory
            ? await _repository.sendFile(
                fileName: picked.name,
                bytes: picked.bytes,
                mimeType: picked.mimeType,
                onProgress: (count, total) {
                  if (isTransferCancelled(tempId)) {
                    throw const TransferCancelledException();
                  }
                  _transfers[tempId] = tracker.update(count, total);
                  _notify();
                },
              )
            : await _repository.sendFileStream(
                fileName: picked.name,
                stream: picked.openRead(),
                size: picked.size,
                mimeType: picked.mimeType,
                onProgress: (count, total) {
                  if (isTransferCancelled(tempId)) {
                    throw const TransferCancelledException();
                  }
                  _transfers[tempId] = tracker.update(count, total);
                  _notify();
                },
              );
        if (realPost.attachment case final realAttachment?
            when realAttachment.isImage &&
                picked.hasBytesInMemory &&
                picked.bytes.length <= attachmentPreviewAutoLimit) {
          previews.remember(realAttachment.id, picked.bytes);
        }
        final hasPending = _posts.any((p) => p.id == tempId);
      if (hasPending) {
        _posts = [for (final p in _posts) p.id == tempId ? realPost : p];
      } else {
        _posts = [..._posts.where((p) => p.id != realPost.id), realPost];
      }
        _transfers.remove(tempId);
        _cancelledTransfers.remove(tempId);
        _notify();
        sent++;
      } catch (e) {
        _posts = _posts.where((p) => p.id != tempId).toList();
        _transfers.remove(tempId);
        if (e is! TransferCancelledException && !isTransferCancelled(tempId)) {
          lastError = e is FileError ? e : FileError(item.file.name, e);
        }
        _cancelledTransfers.remove(tempId);
        _notify();
      }
    }

    _sending = false;
    _error = lastError;
    _notify();
    return sent;
  }

  Future<int> _sendPickedFiles(
    List<PickedFile> picked, {
    String caption = '',
  }) async {
    final trimmedCaption = caption.trim();
    var captionAssigned = false;
    final queue = <({PickedFile file, String tempId, String caption})>[];
    final pendingPosts = <Post>[];
    for (var i = 0; i < picked.length; i++) {
      final file = picked[i];
      final itemCaption = (!captionAssigned && !file.isTooLarge)
          ? trimmedCaption
          : '';
      if (!file.isTooLarge) captionAssigned = true;
      final tempId =
          'pending_${_clock().millisecondsSinceEpoch}_${i}_${file.name}';
      final attachment = Attachment(
        id: tempId,
        fileName: file.name,
        size: file.size,
        mimeType: file.mimeType,
      );
      if (!file.isTooLarge &&
          file.hasBytesInMemory &&
          file.bytes.length <= attachmentPreviewAutoLimit &&
          attachment.isImage) {
        previews.remember(tempId, file.bytes);
      }
      final post = Post(
        id: tempId,
        kind: PostKind.file,
        createdAt: _clock().add(Duration(milliseconds: i)),
        senderDevice: '',
        text: itemCaption,
        attachment: attachment,
      );
      queue.add((file: file, tempId: tempId, caption: itemCaption));
      pendingPosts.add(post);
      _transfers[tempId] = TransferProgress(
        transferred: 0,
        total: file.size,
        bytesPerSecond: 0,
      );
    }

    _posts = [..._posts, ...pendingPosts];
    _sending = true;
    _notify();

    var sent = 0;
    Object? lastError;
    for (final item in queue) {
      final tempId = item.tempId;
      final file = item.file;
      if (isTransferCancelled(tempId)) {
        _cancelledTransfers.remove(tempId);
        _transfers.remove(tempId);
        _posts = _posts.where((p) => p.id != tempId).toList();
        _notify();
        continue;
      }
      try {
        if (file.isTooLarge || file.size > _repository.maxFileSize) {
          throw FileTooLargeException(file.size, _repository.maxFileSize);
        }
        final tracker = TransferTracker(clock: _clock);
        _transfers[tempId] = tracker.update(0, file.size);
        _notify();

        final realPost = file.hasBytesInMemory
            ? await _repository.sendFile(
                fileName: file.name,
                bytes: file.bytes,
                mimeType: file.mimeType,
                caption: item.caption,
                onProgress: (count, total) {
                  if (isTransferCancelled(tempId)) {
                    throw const TransferCancelledException();
                  }
                  _transfers[tempId] = tracker.update(count, total);
                  _notify();
                },
              )
            : await _repository.sendFileStream(
                fileName: file.name,
                stream: file.openRead(),
                size: file.size,
                mimeType: file.mimeType,
                caption: item.caption,
                onProgress: (count, total) {
                  if (isTransferCancelled(tempId)) {
                    throw const TransferCancelledException();
                  }
                  _transfers[tempId] = tracker.update(count, total);
                  _notify();
                },
              );
        if (realPost.attachment case final realAttachment?
            when realAttachment.isImage &&
                file.hasBytesInMemory &&
                file.bytes.length <= attachmentPreviewAutoLimit) {
          previews.remember(realAttachment.id, file.bytes);
        }
        final hasPending = _posts.any((p) => p.id == tempId);
      if (hasPending) {
        _posts = [for (final p in _posts) p.id == tempId ? realPost : p];
      } else {
        _posts = [..._posts.where((p) => p.id != realPost.id), realPost];
      }
        _transfers.remove(tempId);
        _cancelledTransfers.remove(tempId);
        _notify();
        sent++;
      } catch (e) {
        _posts = _posts.where((p) => p.id != tempId).toList();
        _transfers.remove(tempId);
        if (e is! TransferCancelledException && !isTransferCancelled(tempId)) {
          lastError = (picked.length > 1 && e is! FileError)
              ? FileError(file.name, e)
              : e;
        }
        _cancelledTransfers.remove(tempId);
        _notify();
      }
    }

    _sending = _transfers.isNotEmpty;
    _error = lastError;
    _notify();
    return sent;
  }

  /// Удаляет все посты базы на всех устройствах. Возвращает число удалённых.
  Future<int> clearAll() async {
    var deleted = 0;
    _error = null;
    _selected.clear();
    for (final post in List.of(_posts)) {
      try {
        await _repository.deletePost(post);
        _posts = _posts.where((p) => p.id != post.id).toList();
        deleted++;
      } catch (e) {
        _error = e;
      }
      _notify();
    }
    return deleted;
  }

  /// Скачивает и расшифровывает файл поста, затем предлагает его сохранить.
  /// Возвращает `true`, если файл сохранён.
  Future<bool> saveAttachment(Post post) async {
    final attachment = post.attachment;
    if (attachment == null || _saving.contains(post.id)) return false;
    _saving.add(post.id);
    _notify();
    try {
      final cached = previews.peek(attachment);
      final Uint8List bytes;
      if (cached != null) {
        bytes = cached;
      } else {
        final tracker = TransferTracker(clock: _clock);
        _transfers[post.id] = tracker.update(0, attachment.size);
        _notify();
        bytes = await _repository.downloadAttachment(
          attachment,
          onProgress: (count, total) {
            _transfers[post.id] = tracker.update(count, total);
            _notify();
          },
        );
      }
      final saved = await _files.saveFile(
        fileName: attachment.fileName,
        bytes: bytes,
        mimeType: attachment.mimeType,
      );
      _error = null;
      return saved;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _saving.remove(post.id);
      _transfers.remove(post.id);
      _notify();
    }
  }

  /// Скачивает и расшифровывает все файлы папки, сохраняя структуру каталогов на диск
  /// (или единым zip-архивом в вебе).
  Future<bool> saveFolder(Post post) async {
    final folder = post.folder;
    if (folder == null || _saving.contains(post.id)) return false;
    _saving.add(post.id);
    _notify();
    try {
      final tracker = TransferTracker(clock: _clock);
      _transfers[post.id] = tracker.update(0, folder.totalSize);
      _notify();

      final progressByEntry = <String, int>{};
      void updateFolderProgress() {
        var sum = 0;
        for (final v in progressByEntry.values) {
          sum += v;
        }
        _transfers[post.id] = tracker.update(sum, folder.totalSize);
        _notify();
      }

      final saved = await _files.saveFolder(
        folderName: folder.name,
        entries: folder.files,
        getFileBytes: (entryAttachment) async {
          final bytes = await _repository.downloadAttachment(
            entryAttachment,
            onProgress: (count, total) {
              progressByEntry[entryAttachment.id] =
                  total > 0
                      ? (count / total * entryAttachment.size).toInt()
                      : count;
              updateFolderProgress();
            },
          );
          progressByEntry[entryAttachment.id] = entryAttachment.size;
          updateFolderProgress();
          return bytes;
        },
      );
      _error = null;
      return saved;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _saving.remove(post.id);
      _transfers.remove(post.id);
      _notify();
    }
  }

  /// Сохраняет отдельный файл из папки.
  Future<bool> saveFolderEntry(FolderEntry entry) async {
    try {
      final bytes = await _repository.downloadAttachment(entry.toAttachment());
      return await _files.saveFile(
        fileName: entry.fileName,
        bytes: bytes,
        mimeType: entry.mimeType,
      );
    } catch (e) {
      _error = e;
      _notify();
      return false;
    }
  }

  /// Задаёт комментарий к посту; пустой текст удаляет его.
  /// Возвращает `true`, если изменение сохранено в облаке.
  Future<bool> setNote(Post post, String text) async {
    try {
      final updated = await _repository.setNote(post, text);
      _posts = [for (final p in _posts) p.id == post.id ? updated : p];
      _error = null;
      return true;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _notify();
    }
  }

  /// Обновляет содержимое файла поста (например, после редактирования текста
  /// прямо в приложении) и синхронизирует кеш превью.
  Future<Post?> updateFileContent(
    Post post,
    Uint8List bytes, {
    String? fileName,
    String? mimeType,
  }) async {
    try {
      final updated = await _repository.updateFileContent(
        post: post,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      if (updated.attachment case final newAtt?) {
        previews.remember(newAtt.id, bytes);
      }
      _posts = [for (final p in _posts) p.id == post.id ? updated : p];
      _error = null;
      _notify();
      return updated;
    } catch (e) {
      _error = e;
      _notify();
      return null;
    }
  }

  /// Обновляет структуру папки поста (переименование, перемещение или удаление
  /// файлов и подпапок). Возвращает обновлённый пост или `null`, если папка
  /// стала пустой и пост был удалён (или произошла ошибка).
  Future<Post?> updateFolderStructure(
    Post post,
    FolderAttachment updatedFolder, {
    List<String> removedEntryIds = const [],
  }) async {
    try {
      final updated = await _repository.updateFolderStructure(
        post: post,
        updatedFolder: updatedFolder,
        removedEntryIds: removedEntryIds,
      );
      if (updated == null) {
        _posts = _posts.where((p) => p.id != post.id).toList();
        _selected.remove(post.id);
      } else {
        _posts = [for (final p in _posts) p.id == post.id ? updated : p];
      }
      _error = null;
      _notify();
      return updated;
    } catch (e) {
      _error = e;
      _notify();
      return post;
    }
  }

  /// Заменяет один файл [entryId] внутри папки поста новыми байтами [bytes]
  /// (например, после редактирования текстового файла или выбора замены с диска).
  Future<Post?> replaceFolderEntry(
    Post post,
    String entryId,
    Uint8List bytes, {
    String? newRelativePath,
    String? mimeType,
  }) async {
    try {
      final updated = await _repository.replaceFolderEntry(
        post: post,
        entryId: entryId,
        bytes: bytes,
        newRelativePath: newRelativePath,
        mimeType: mimeType,
      );
      final newEntry = updated.folder?.files.firstWhere(
        (e) =>
            e.relativePath ==
            (newRelativePath ??
                post.folder?.files
                    .firstWhere((old) => old.id == entryId)
                    .relativePath),
        orElse: () => updated.folder!.files.first,
      );
      if (newEntry != null) {
        previews.remember(newEntry.id, bytes);
      }
      _posts = [for (final p in _posts) p.id == post.id ? updated : p];
      _error = null;
      _notify();
      return updated;
    } catch (e) {
      _error = e;
      _notify();
      return null;
    }
  }

  /// Предлагает выбрать один файл на устройстве и заменяет им элемент
  /// [entry] внутри папки поста [post].
  Future<Post?> pickAndReplaceFolderEntry(Post post, FolderEntry entry) async {
    final List<PickedFile> picked;
    try {
      picked = await _files.pickFiles(maxSize: _repository.maxFileSize);
    } catch (e) {
      _error = e;
      _notify();
      return null;
    }
    if (picked.isEmpty) return null;
    final file = picked.first;
    if (file.isTooLarge || file.size > _repository.maxFileSize) {
      _error = FileTooLargeException(file.size, _repository.maxFileSize);
      _notify();
      return null;
    }
    final Uint8List bytes;
    if (file.hasBytesInMemory) {
      bytes = file.bytes;
    } else {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.openRead()) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    }
    final slash = entry.relativePath.lastIndexOf('/');
    final dirPrefix = slash < 0 ? '' : entry.relativePath.substring(0, slash + 1);
    final newPath = '$dirPrefix${file.name}';
    return replaceFolderEntry(
      post,
      entry.id,
      bytes,
      newRelativePath: newPath,
      mimeType: file.mimeType,
    );
  }

  /// Предлагает выбрать один или несколько файлов на устройстве и добавляет их
  /// в подкаталог [targetSubdir] папки поста [post].
  Future<Post?> pickAndAddFilesToFolder(
    Post post, {
    String targetSubdir = '',
  }) async {
    final List<PickedFile> picked;
    try {
      picked = await _files.pickFiles(maxSize: _repository.maxFileSize);
    } catch (e) {
      _error = e;
      _notify();
      return null;
    }
    if (picked.isEmpty) return null;
    try {
      final updated = await _repository.addFilesToFolder(
        post: post,
        files: picked,
        targetSubdir: targetSubdir,
      );
      _posts = [for (final p in _posts) p.id == post.id ? updated : p];
      _error = null;
      _notify();
      return updated;
    } catch (e) {
      _error = e;
      _notify();
      return null;
    }
  }

  Future<void> delete(Post post) async {
    try {
      await _repository.deletePost(post);
      _posts = _posts.where((p) => p.id != post.id).toList();
      _selected.remove(post.id);
      _error = null;
    } catch (e) {
      _error = e;
    }
    _notify();
  }

  Future<bool> _runSend(Future<Post> Function() send) async {
    if (_sending) return false;
    _sending = true;
    _notify();
    try {
      final post = await send();
      _posts = [..._posts.where((p) => p.id != post.id), post];
      _error = null;
      return true;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _sending = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
