import 'package:flutter/foundation.dart';

enum PostKind { text, link, file, folder }

/// Описание прикреплённого файла. Сами байты лежат в облаке отдельно.
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.size,
    this.mimeType,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'] as String,
    fileName: json['name'] as String,
    size: (json['size'] as num).toInt(),
    mimeType: json['mime'] as String?,
  );

  final String id;
  final String fileName;
  final int size;
  final String? mimeType;

  static const _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', //
  };

  /// Фото, которое можно показать в ленте (по типу или расширению). Если
  /// формат не поддерживается на устройстве, запись показывается как файл.
  bool get isImage {
    final mime = mimeType;
    if (mime != null && mime.startsWith('image/')) return !mime.contains('svg');
    return _imageExtensions.contains(_extension);
  }

  static const _textExtensions = {
    'txt', 'text', 'md', 'markdown', 'csv', 'tsv', 'json', 'xml', 'log', //
    'ini', 'conf', 'cfg', 'yaml', 'yml', 'toml', 'srt', 'vtt', 'sub',
    'html', 'htm', 'css', 'js', 'ts', 'dart', 'py', 'java', 'kt', 'swift',
    'c', 'h', 'cpp', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'sh', 'bat',
    'ps1', 'sql', 'svg',
  };

  /// Текстовый файл, который можно прочитать прямо в приложении.
  bool get isText {
    if (_textExtensions.contains(_extension)) return true;
    final mime = mimeType ?? '';
    return mime.startsWith('text/') ||
        mime == 'application/json' ||
        mime == 'application/xml';
  }

  /// Markdown — показывается с оформлением.
  bool get isMarkdown =>
      _extension == 'md' ||
      _extension == 'markdown' ||
      mimeType == 'text/markdown';

  /// Документ Word (.docx) — показывается его текст.
  bool get isDocx =>
      _extension == 'docx' ||
      mimeType ==
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  static const _videoExtensions = {
    'mp4', 'm4v', 'mov', 'webm', 'mkv', 'avi', '3gp', 'wmv', 'mpg', 'mpeg', //
  };
  static const _audioExtensions = {
    'mp3', 'm4a', 'aac', 'ogg', 'oga', 'opus', 'flac', 'wav', 'wma', 'amr', //
  };

  /// Видео — играет встроенный плеер (или другое приложение).
  bool get isVideo =>
      _videoExtensions.contains(_extension) ||
      (mimeType?.startsWith('video/') ?? false);

  /// Музыка и голосовые — играет встроенный плеер (или другое приложение).
  bool get isAudio =>
      _audioExtensions.contains(_extension) ||
      (mimeType?.startsWith('audio/') ?? false);

  /// Можно прочитать прямо в приложении: текст, Markdown или .docx.
  bool get isReadable => isText || isDocx;

  /// Расширение имени файла в нижнем регистре (без точки).
  String get _extension {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': fileName,
    'size': size,
    if (mimeType != null) 'mime': mimeType,
  };
}

/// Один файл внутри прикреплённой папки.
@immutable
class FolderEntry {
  const FolderEntry({
    required this.id,
    required this.relativePath,
    required this.size,
    this.mimeType,
  });

  factory FolderEntry.fromJson(Map<String, dynamic> json) => FolderEntry(
    id: json['id'] as String,
    relativePath: json['path'] as String,
    size: (json['size'] as num).toInt(),
    mimeType: json['mime'] as String?,
  );

  final String id;

  /// Относительный путь файла внутри папки (например, `sub/file.txt`),
  /// разделитель всегда `/`.
  final String relativePath;
  final int size;
  final String? mimeType;

  /// Имя файла без пути.
  String get fileName => relativePath.split('/').last;

  /// Преобразует элемент папки во вложение [Attachment] для открытия
  /// во встроенных просмотрщиках или сохранения отдельного файла.
  Attachment toAttachment() => Attachment(
    id: id,
    fileName: fileName,
    size: size,
    mimeType: mimeType,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': relativePath,
    'size': size,
    if (mimeType != null) 'mime': mimeType,
  };
}

/// Прикреплённая папка со структурой файлов и каталогов.
@immutable
class FolderAttachment {
  const FolderAttachment({
    required this.name,
    required this.files,
  });

  factory FolderAttachment.fromJson(Map<String, dynamic> json) =>
      FolderAttachment(
        name: json['name'] as String,
        files: [
          for (final item in (json['files'] as List))
            FolderEntry.fromJson(item as Map<String, dynamic>),
        ],
      );

  final String name;
  final List<FolderEntry> files;

  int get fileCount => files.length;
  int get totalSize => files.fold(0, (sum, f) => sum + f.size);

  Map<String, dynamic> toJson() => {
    'name': name,
    'files': [for (final f in files) f.toJson()],
  };
}

/// Комментарий к записи: пояснение, которое можно добавить, изменить или
/// удалить с любого устройства базы. Хранится отдельно от записи.
@immutable
class PostNote {
  const PostNote({
    required this.postId,
    required this.text,
    required this.editedAt,
    required this.editorDevice,
  });

  factory PostNote.fromJson(Map<String, dynamic> json) => PostNote(
    postId: json['post'] as String,
    text: json['text'] as String,
    editedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['ts'] as num).toInt(),
      isUtc: true,
    ),
    editorDevice: (json['from'] as String?) ?? '',
  );

  final String postId;
  final String text;
  final DateTime editedAt;

  /// Устройство, с которого комментарий изменили последним.
  final String editorDevice;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'post': postId,
    'text': text,
    'ts': editedAt.toUtc().millisecondsSinceEpoch,
    'from': editorDevice,
  };
}

/// Одна запись в базе: текст, ссылка, файл или папка.
@immutable
class Post {
  const Post({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.senderDevice,
    this.text = '',
    this.attachment,
    this.folder,
    this.note,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    kind: PostKind.values.asNameMap()[json['kind'] as String] ?? PostKind.file,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['ts'] as num).toInt(),
      isUtc: true,
    ),
    senderDevice: (json['from'] as String?) ?? '',
    text: (json['text'] as String?) ?? '',
    attachment: json['file'] == null
        ? null
        : Attachment.fromJson(json['file'] as Map<String, dynamic>),
    folder: json['folder'] == null
        ? null
        : FolderAttachment.fromJson(json['folder'] as Map<String, dynamic>),
  );

  final String id;
  final PostKind kind;
  final DateTime createdAt;
  final String senderDevice;

  /// Текст сообщения, адрес ссылки или подпись к файлу/папке.
  final String text;
  final Attachment? attachment;
  final FolderAttachment? folder;

  /// Комментарий к записи. В JSON записи не входит: хранится отдельно.
  final PostNote? note;

  /// Та же запись с другим комментарием (`null` — без комментария).
  Post withNote(PostNote? note) => Post(
    id: id,
    kind: kind,
    createdAt: createdAt,
    senderDevice: senderDevice,
    text: text,
    attachment: attachment,
    folder: folder,
    note: note,
  );

  /// Та же запись с обновлённым прикреплённым файлом.
  Post withAttachment(Attachment attachment) => Post(
    id: id,
    kind: kind,
    createdAt: createdAt,
    senderDevice: senderDevice,
    text: text,
    attachment: attachment,
    folder: folder,
    note: note,
  );

  /// Та же запись с обновлённой прикреплённой папкой.
  Post withFolder(FolderAttachment folder) => Post(
    id: id,
    kind: kind,
    createdAt: createdAt,
    senderDevice: senderDevice,
    text: text,
    attachment: attachment,
    folder: folder,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'v': 1,
    'id': id,
    'kind': kind.name,
    'ts': createdAt.toUtc().millisecondsSinceEpoch,
    'from': senderDevice,
    'text': text,
    if (attachment != null) 'file': attachment!.toJson(),
    if (folder != null) 'folder': folder!.toJson(),
  };
}
