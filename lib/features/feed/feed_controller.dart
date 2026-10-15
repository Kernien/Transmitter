import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_error.dart';
import '../../core/files/file_transfer_service.dart';
import '../../core/files/media_picker.dart';
import '../../core/share/outgoing_share.dart';
import '../../core/utils/clock.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';
import 'selection_exporter.dart';

/// Состояние ленты одной базы: загрузка, периодический опрос облака,
/// отправка, удаление постов и сохранение файлов.
class FeedController extends ChangeNotifier {
  FeedController(
    this._repository, {
    required this._files,
    required this._pollInterval,
    this._media = const NoMediaPicker(),
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
  final Set<String> _selected = {};
  Object? _error;

  List<Post> get posts => _posts;
  bool get isInitialLoad => _initialLoad;
  bool get isSending => _sending;

  /// Последняя ошибка; текст на языке интерфейса — `describeError`.
  Object? get error => _error;

  /// Идёт ли сейчас скачивание файла из этого поста.
  bool isSaving(Post post) => _saving.contains(post.id);

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
      for (final post in ordered)
        if (post.attachment case final attachment?)
          OutgoingFile(
            name: attachment.fileName,
            bytes: await _repository.downloadAttachment(attachment),
            mimeType: attachment.mimeType,
          ),
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
    refresh();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      _posts = await _repository.fetchPosts();
      // Посты, удалённые на других устройствах, больше нельзя выбрать.
      final ids = _posts.map((p) => p.id).toSet();
      _selected.retainWhere(ids.contains);
      // Например, не удалось обновить публичную доску: лента работает,
      // но владелец должен об этом знать.
      _error = _repository.backgroundError;
    } catch (e) {
      _error = e;
    } finally {
      _refreshing = false;
      _initialLoad = false;
      _notify();
    }
  }

  /// Возвращает `true`, если сообщение отправлено.
  Future<bool> sendText(String text) =>
      _runSend(() => _repository.sendText(text));

  /// Предлагает выбрать файл и отправляет его с подписью [caption].
  /// Возвращает `true`, если файл отправлен (`false` — отмена или ошибка).
  Future<bool> attachFile({String caption = ''}) => _attach(
    () => _files.pickFile(maxSize: _repository.maxFileSize),
    caption: caption,
  );

  /// Можно ли выбрать фото или видео в Галерее (на телефоне).
  bool get canAttachMedia => _media.isAvailable;

  /// Как [attachFile], но фото или видео выбирается в Галерее.
  Future<bool> attachMedia({String caption = ''}) => _attach(
    () => _media.pickMedia(maxSize: _repository.maxFileSize),
    caption: caption,
  );

  Future<bool> _attach(
    Future<PickedFile?> Function() pick, {
    required String caption,
  }) async {
    if (_sending) return false;
    final PickedFile? picked;
    try {
      picked = await pick();
    } catch (e) {
      _error = e;
      _notify();
      return false;
    }
    if (picked == null) return false;
    return _sendPicked(picked, caption: caption);
  }

  /// Отправляет файлы, перетащенные в окно, по очереди.
  /// Возвращает, сколько файлов отправлено; ошибки попадают в [error].
  Future<int> sendDroppedFiles(List<XFile> files) async {
    var sent = 0;
    Object? lastError;
    for (final file in files) {
      try {
        final picked = await _files.readFile(
          file,
          maxSize: _repository.maxFileSize,
        );
        if (await _sendPicked(picked)) {
          sent++;
        } else {
          lastError = _error;
        }
      } catch (e) {
        lastError = FileError(file.name, e);
      }
    }
    _error = lastError;
    _notify();
    return sent;
  }

  Future<bool> _sendPicked(PickedFile picked, {String caption = ''}) =>
      _runSend(
        () => _repository.sendFile(
          fileName: picked.name,
          bytes: picked.bytes,
          mimeType: picked.mimeType,
          caption: caption,
        ),
      );

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
      final bytes = await _repository.downloadAttachment(attachment);
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
      _notify();
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
