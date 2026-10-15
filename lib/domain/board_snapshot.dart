import 'package:flutter/foundation.dart';

import 'post.dart';

/// Опись публичной доски: всё, что видит читатель. Владелец обновляет её
/// при каждом изменении базы.
@immutable
class BoardSnapshot {
  const BoardSnapshot({
    required this.label,
    required this.updatedAt,
    required this.posts,
    required this.fileLocators,
  });

  factory BoardSnapshot.fromJson(Map<String, dynamic> json) => BoardSnapshot(
    label: (json['label'] as String?) ?? '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['ts'] as num).toInt(),
      isUtc: true,
    ),
    posts: [
      for (final raw in (json['posts'] as List).cast<Map<String, dynamic>>())
        Post.fromJson(raw).withNote(
          raw['note'] == null
              ? null
              : PostNote.fromJson(raw['note'] as Map<String, dynamic>),
        ),
    ],
    fileLocators: (json['files'] as Map<String, dynamic>).map(
      (id, locator) => MapEntry(id, locator as String),
    ),
  );

  /// Название доски у владельца.
  final String label;
  final DateTime updatedAt;

  /// Записи от старых к новым, вместе с комментариями.
  final List<Post> posts;

  /// Адреса открытых по ссылке файлов: id вложения → локатор облака.
  final Map<String, String> fileLocators;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'label': label,
    'ts': updatedAt.toUtc().millisecondsSinceEpoch,
    'posts': [
      for (final post in posts)
        {...post.toJson(), if (post.note != null) 'note': post.note!.toJson()},
    ],
    'files': fileLocators,
  };
}
