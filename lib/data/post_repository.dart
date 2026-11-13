import 'dart:typed_data';

import '../core/files/file_transfer_service.dart';
import '../core/storage/cloud_storage.dart';
import '../domain/post.dart';

export '../core/files/file_transfer_service.dart'
    show FileTooLargeException, PickedFile;
export '../core/storage/cloud_storage.dart' show ProgressCallback;

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

  /// Подхватывает записи, сохранённые на устройстве с прошлого раза, без
  /// обращения к облаку. После этого [cachedPosts] может стать не `null`.
  Future<void> warmUp();

  /// Отправляет текст. Если текст — одна ссылка, пост получает тип
  /// [PostKind.link].
  Future<Post> sendText(String text);

  /// Бросает [FileTooLargeException], если файл больше [maxFileSize].
  Future<Post> sendFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String caption = '',
    ProgressCallback? onProgress,
  });

  /// Потоковая отправка файла известного размера [size] без загрузки всего
  /// файла в память. Бросает [FileTooLargeException], если [size] больше [maxFileSize].
  Future<Post> sendFileStream({
    required String fileName,
    required Stream<List<int>> stream,
    required int size,
    String? mimeType,
    String caption = '',
    ProgressCallback? onProgress,
  });

  /// Отправляет папку с файлами единым постом со структурой каталогов.
  /// Бросает [FileTooLargeException], если какой-либо файл больше [maxFileSize],
  /// или [TransferCancelledException], если передача была отменена.
  Future<Post> sendFolder({
    required String folderName,
    required List<PickedFile> files,
    String caption = '',
    ProgressCallback? onProgress,
    bool Function()? isCancelled,
  });

  Future<Uint8List> downloadAttachment(
    Attachment attachment, {
    ProgressCallback? onProgress,
  });

  /// Потоковое скачивание и расшифровка файла вложения.
  Stream<Uint8List> downloadAttachmentStream(
    Attachment attachment, {
    ProgressCallback? onProgress,
  });

  /// Удаляет пост вместе с файлом и комментарием.
  Future<void> deletePost(Post post);

  /// Задаёт комментарий к посту; пустой текст удаляет комментарий.
  /// Возвращает пост с новым комментарием.
  Future<Post> setNote(Post post, String text);

  /// Заменяет содержимое отдельного поста-файла новыми байтами [bytes].
  Future<Post> updateFileContent({
    required Post post,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
    ProgressCallback? onProgress,
  });

  /// Обновляет структуру папки поста (переименование, перемещение или удаление
  /// вложенных файлов и подпапок). Удаляет из облака файлы с идентификаторами
  /// [removedEntryIds]. Если в [updatedFolder] не осталось ни одного файла,
  /// удаляет сам пост и возвращает `null`.
  Future<Post?> updateFolderStructure({
    required Post post,
    required FolderAttachment updatedFolder,
    List<String> removedEntryIds = const [],
  });

  /// Заменяет один файл [entryId] внутри папки поста новыми байтами [bytes].
  Future<Post> replaceFolderEntry({
    required Post post,
    required String entryId,
    required Uint8List bytes,
    String? newRelativePath,
    String? mimeType,
    ProgressCallback? onProgress,
  });

  /// Добавляет новые файлы [files] в существующую папку поста в подкаталог
  /// [targetSubdir] (пустая строка — в корень папки).
  Future<Post> addFilesToFolder({
    required Post post,
    required List<PickedFile> files,
    String targetSubdir = '',
    ProgressCallback? onProgress,
    bool Function()? isCancelled,
  });
}

/// Исключение при отмене передачи файлов пользователем.
class TransferCancelledException implements Exception {
  const TransferCancelledException();

  @override
  String toString() => 'Transfer cancelled';
}
