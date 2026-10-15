import 'package:flutter/foundation.dart';

enum PostKind { text, link, file }

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': fileName,
    'size': size,
    if (mimeType != null) 'mime': mimeType,
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

/// Одна запись в базе: текст, ссылка или файл.
@immutable
class Post {
  const Post({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.senderDevice,
    this.text = '',
    this.attachment,
    this.note,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    kind: PostKind.values.byName(json['kind'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['ts'] as num).toInt(),
      isUtc: true,
    ),
    senderDevice: (json['from'] as String?) ?? '',
    text: (json['text'] as String?) ?? '',
    attachment: json['file'] == null
        ? null
        : Attachment.fromJson(json['file'] as Map<String, dynamic>),
  );

  final String id;
  final PostKind kind;
  final DateTime createdAt;
  final String senderDevice;

  /// Текст сообщения, адрес ссылки или подпись к файлу.
  final String text;
  final Attachment? attachment;

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
  };
}
