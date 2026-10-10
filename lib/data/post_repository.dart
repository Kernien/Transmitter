import 'dart:typed_data';

import '../core/files/file_transfer_service.dart';
import '../domain/post.dart';

export '../core/files/file_transfer_service.dart' show FileTooLargeException;

/// Работа с постами одной базы. UI зависит только от этого интерфейса.
abstract interface class PostRepository {
  /// Максимальный размер прикреплённого файла в этой базе (задаётся в ключе).
  int get maxFileSize;

  /// Все посты базы, от старых к новым. Повторные вызовы скачивают только
  /// новые посты.
  Future<List<Post>> fetchPosts();

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

  Future<void> deletePost(Post post);
}
