import 'dart:typed_data';

import '../domain/post.dart';

/// Работа с постами одной базы. UI зависит только от этого интерфейса.
abstract interface class PostRepository {
  /// Максимальный размер прикреплённого файла.
  static const int maxFileSize = 25 * 1024 * 1024;

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

class FileTooLargeException implements Exception {
  const FileTooLargeException(this.size);

  final int size;

  @override
  String toString() => 'Файл больше '
      '${PostRepository.maxFileSize ~/ (1024 * 1024)} МБ';
}
