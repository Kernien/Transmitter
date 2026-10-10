import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/files/file_transfer_service.dart';
import '../../core/storage/cloud_storage.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';

/// Состояние ленты одной базы: загрузка, периодический опрос облака,
/// отправка, удаление постов и сохранение файлов.
class FeedController extends ChangeNotifier {
  FeedController(
    this._repository, {
    required this._files,
    required this._pollInterval,
  });

  final PostRepository _repository;
  final FileTransferService _files;
  final Duration _pollInterval;
  Timer? _timer;
  bool _refreshing = false;
  bool _disposed = false;

  List<Post> _posts = const [];
  bool _initialLoad = true;
  bool _sending = false;
  final Set<String> _saving = {};
  String? _error;

  List<Post> get posts => _posts;
  bool get isInitialLoad => _initialLoad;
  bool get isSending => _sending;
  String? get error => _error;

  /// Идёт ли сейчас скачивание файла из этого поста.
  bool isSaving(Post post) => _saving.contains(post.id);

  void start() {
    refresh();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      _posts = await _repository.fetchPosts();
      _error = null;
    } catch (e) {
      _error = _describe(e);
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
  Future<bool> attachFile({String caption = ''}) async {
    if (_sending) return false;
    final PickedFile? picked;
    try {
      picked = await _files.pickFile(maxSize: PostRepository.maxFileSize);
    } catch (e) {
      _error = _describe(e);
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
    String? lastError;
    for (final file in files) {
      try {
        final picked = await _files.readFile(file, maxSize: PostRepository.maxFileSize);
        if (await _sendPicked(picked)) {
          sent++;
        } else {
          lastError = _error;
        }
      } catch (e) {
        lastError = '${file.name}: ${_describe(e)}';
      }
    }
    _error = lastError;
    _notify();
    return sent;
  }

  Future<bool> _sendPicked(PickedFile picked, {String caption = ''}) =>
      _runSend(() => _repository.sendFile(
            fileName: picked.name,
            bytes: picked.bytes,
            mimeType: picked.mimeType,
            caption: caption,
          ));

  /// Удаляет все посты базы на всех устройствах. Возвращает число удалённых.
  Future<int> clearAll() async {
    var deleted = 0;
    _error = null;
    for (final post in List.of(_posts)) {
      try {
        await _repository.deletePost(post);
        _posts = _posts.where((p) => p.id != post.id).toList();
        deleted++;
      } catch (e) {
        _error = _describe(e);
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
      _error = _describe(e);
      return false;
    } finally {
      _saving.remove(post.id);
      _notify();
    }
  }

  Future<void> delete(Post post) async {
    try {
      await _repository.deletePost(post);
      _posts = _posts.where((p) => p.id != post.id).toList();
      _error = null;
    } catch (e) {
      _error = _describe(e);
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
      _error = _describe(e);
      return false;
    } finally {
      _sending = false;
      _notify();
    }
  }

  static String _describe(Object error) => switch (error) {
        StorageNotFoundException _ => 'Файл уже удалён из облака',
        StorageException e => e.message,
        FileTooLargeException e => e.toString(),
        _ => 'Ошибка: $error',
      };

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
