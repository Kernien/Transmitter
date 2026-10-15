import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/post.dart';
import 'board_publisher.dart';
import 'post_repository.dart';

/// Обёртка над репозиторием владельца: после чтения ленты и каждого
/// изменения обновляет опись публичной доски (если доступ на чтение открыт).
///
/// Обновление идёт в фоне и не задерживает ленту; его ошибка видна в
/// [backgroundError], но не мешает работать с записями.
class PublishingPostRepository implements PostRepository {
  PublishingPostRepository(this._inner, this._publisher);

  final PostRepository _inner;
  final BoardPublisher _publisher;

  Object? _error;
  List<Post>? _latest;
  Future<void>? _running;
  Future<void>? _refreshing;
  bool _again = false;

  @override
  int get maxFileSize => _inner.maxFileSize;

  @override
  Object? get backgroundError => _error ?? _inner.backgroundError;

  /// Завершение фонового обновления описи (для тестов).
  @visibleForTesting
  Future<void> get idle async {
    await _refreshing;
    while (_running != null) {
      await _running;
    }
  }

  @override
  Future<List<Post>> fetchPosts() async {
    final posts = await _inner.fetchPosts();
    _schedule(posts);
    return posts;
  }

  @override
  Future<Post> sendText(String text) => _changed(_inner.sendText(text));

  @override
  Future<Post> sendFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String caption = '',
  }) => _changed(
    _inner.sendFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      caption: caption,
    ),
  );

  @override
  Future<Uint8List> downloadAttachment(Attachment attachment) =>
      _inner.downloadAttachment(attachment);

  @override
  Future<void> deletePost(Post post) => _changed(_inner.deletePost(post));

  @override
  Future<Post> setNote(Post post, String text) =>
      _changed(_inner.setNote(post, text));

  Future<T> _changed<T>(Future<T> change) async {
    final result = await change;
    // Лента уже в кеше репозитория: запрос — только список файлов.
    final refreshing = _inner.fetchPosts().then(_schedule, onError: _remember);
    _refreshing = refreshing;
    unawaited(refreshing);
    return result;
  }

  /// Обновления идут по одному; пришедшие во время обновления записи
  /// попадут в следующий проход.
  void _schedule(List<Post> posts) {
    _latest = posts;
    if (_running != null) {
      _again = true;
      return;
    }
    _running = _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    do {
      _again = false;
      try {
        await _publisher.sync(_latest!);
        _error = null;
      } catch (e) {
        _remember(e);
      }
    } while (_again);
  }

  void _remember(Object error) {
    debugPrint('Board update failed: $error');
    _error = error;
  }
}
