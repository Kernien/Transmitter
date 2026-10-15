import 'dart:typed_data';

import '../core/files/file_transfer_service.dart';
import '../domain/post.dart';

export '../core/files/file_transfer_service.dart' show FileTooLargeException;

/// Работа с постами одной базы. UI зависит только от этого интерфейса.
abstract interface class PostRepository {
  /// Максимальный размер прикреплённого файла в этой базе (задаётся в ключе).
  int get maxFileSize;

  /// Ошибка фоновой работы — например, обновления публичной доски. Лента
  /// при этом работает; `null`, если всё в порядке.
  Object? get backgroundError;

  /// Публичная доска у читателя: записи можно смотреть, копировать и
  /// скачивать, но не добавлять, изменять и удалять.
  bool get isReadOnly;

  /// Все посты базы, от старых к новым. Повторные вызовы скачивают только
  /// новые посты.
  Future<List<Post>> fetchPosts();

  /// Посты, уже известные без обращения к облаку (после прошлого
  /// [fetchPosts]); `null`, если ещё ничего не загружалось. Лента показывает
  /// их сразу, пока идёт обновление.
  List<Post>? get cachedPosts;

  /// Отправляет текст. Если текст — одна ссылка, пост получает тип
  /// [PostKind.link].
  Future<Post> sendText(String text);

  /// Бросает [FileTooLargeException], если файл больше [maxFileSize].
  Future<Post> sendFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String caption = '',
  });

  Future<Uint8List> downloadAttachment(Attachment attachment);

  /// Удаляет пост вместе с файлом и комментарием.
  Future<void> deletePost(Post post);

  /// Задаёт комментарий к посту; пустой текст удаляет комментарий.
  /// Возвращает пост с новым комментарием.
  Future<Post> setNote(Post post, String text);
}
