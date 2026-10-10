import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/storage/cloud_storage.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';

/// Состояние ленты одной базы: загрузка, периодический опрос облака,
/// отправка и удаление постов.
class FeedController extends ChangeNotifier {
  FeedController(this._repository, {required this._pollInterval});

  final PostRepository _repository;
  final Duration _pollInterval;
  Timer? _timer;
  bool _refreshing = false;
  bool _disposed = false;

  List<Post> _posts = const [];
  bool _initialLoad = true;
  bool _sending = false;
  String? _error;

  List<Post> get posts => _posts;
  bool get isInitialLoad => _initialLoad;
  bool get isSending => _sending;
  String? get error => _error;
  PostRepository get repository => _repository;

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

  Future<bool> sendFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) =>
      _runSend(() => _repository.sendFile(
            fileName: fileName,
            bytes: bytes,
            mimeType: mimeType,
          ));

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
