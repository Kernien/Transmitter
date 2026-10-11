import 'dart:convert';
import 'dart:typed_data';

import '../../core/files/zip_bundle.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';

/// Готовый к сохранению результат выгрузки.
class ExportedFile {
  const ExportedFile({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? mimeType;
}

/// Собирает выбранные посты в один файл для сохранения.
///
/// Один файл без текстовых постов сохраняется как есть. Иначе получается
/// zip: файлы + текстовый файл ([ExportTexts.textFileName]) с текстами и
/// ссылками.
class SelectionExporter {
  const SelectionExporter(this._repository, [this.texts = ExportTexts.english]);

  final PostRepository _repository;

  /// Имена и пометки внутри архива — на языке интерфейса.
  final ExportTexts texts;

  /// Бросает исключения хранилища, если файл не удалось скачать.
  Future<ExportedFile> export(List<Post> posts, {required DateTime now}) async {
    final ordered = [...posts]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final filePosts = ordered.where((p) => p.attachment != null).toList();
    final textPosts = ordered.where((p) => p.attachment == null).toList();

    if (filePosts.length == 1 && textPosts.isEmpty) {
      final attachment = filePosts.single.attachment!;
      return ExportedFile(
        fileName: attachment.fileName,
        bytes: await _repository.downloadAttachment(attachment),
        mimeType: attachment.mimeType,
      );
    }

    final entries = <BundleEntry>[
      for (final post in filePosts)
        BundleEntry(
          post.attachment!.fileName,
          await _repository.downloadAttachment(post.attachment!),
        ),
    ];
    final messages = ordered.where((p) => p.text.isNotEmpty).toList();
    if (messages.isNotEmpty) {
      entries.add(BundleEntry(texts.textFileName, _messagesText(messages)));
    }

    return ExportedFile(
      fileName: 'transmitter_${_stamp(now)}.zip',
      bytes: await buildZip(entries),
      mimeType: 'application/zip',
    );
  }

  /// Тексты, ссылки и подписи к файлам в хронологическом порядке.
  /// BOM нужен, чтобы Блокнот Windows правильно открыл кириллицу.
  Uint8List _messagesText(List<Post> posts) {
    final buffer = StringBuffer(String.fromCharCode(0xFEFF));
    for (final post in posts) {
      final file = post.attachment == null
          ? ''
          : ' · ${texts.fileNote(post.attachment!.fileName)}';
      buffer
        ..write(
          '[${_stamp(post.createdAt.toLocal(), human: true)}] ${post.senderDevice}$file\r\n',
        )
        ..write(post.text.replaceAll('\n', '\r\n'))
        ..write('\r\n\r\n');
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _stamp(DateTime t, {bool human = false}) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${t.year}-${two(t.month)}-${two(t.day)}';
    return human
        ? '$date ${two(t.hour)}:${two(t.minute)}'
        : '${date}_${two(t.hour)}-${two(t.minute)}';
  }
}

/// Тексты внутри архива выгрузки. Передаются с экрана на языке интерфейса.
class ExportTexts {
  const ExportTexts({required this.textFileName, required this.fileNote});

  static const english = ExportTexts(
    textFileName: 'items.txt',
    fileNote: _englishFileNote,
  );

  /// Имя текстового файла с записями в архиве («items.txt» / «записи.txt»).
  final String textFileName;

  /// Пометка о файле у подписи: «file photo.jpg» / «файл photo.jpg».
  final String Function(String fileName) fileNote;

  static String _englishFileNote(String name) => 'file $name';
}
