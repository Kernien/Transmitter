import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import '../../../domain/post.dart';
import '../file_transfer_service.dart';

bool get isDirectorySupported => true;

Future<PickedFolder?> readDirectoryFromPath(
  String path, {
  required int maxSize,
  required int inMemoryThreshold,
}) async {
  final dir = Directory(path);
  if (!await dir.exists()) return null;

  final normPath = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final parts = normPath.split('/').where((s) => s.isNotEmpty).toList();
  final folderName = parts.isEmpty ? 'folder' : parts.last;

  final files = <PickedFile>[];
  final entities = dir.listSync(recursive: true, followLinks: false);

  for (final entity in entities) {
    if (entity is! File) continue;
    final entityNorm = entity.path.replaceAll('\\', '/');
    var rel = entityNorm.substring(normPath.length);
    if (rel.startsWith('/')) rel = rel.substring(1);

    final fileName = entity.uri.pathSegments.last;
    final mimeType = lookupMimeType(fileName);
    int size;
    try {
      size = entity.lengthSync();
    } on FileSystemException {
      // Пропускаем недоступные или удалённые временные файлы (например, блокировка ОС).
      continue;
    }

    if (size > maxSize) {
      files.add(
        PickedFile.tooLarge(
          name: fileName,
          size: size,
          mimeType: mimeType,
          relativePath: rel,
        ),
      );
      continue;
    }

    // Потоковое чтение по требованию: не читаем все файлы сразу в память
    // при сканировании каталога, благодаря чему папка появляется на доске мгновенно.
    files.add(
      PickedFile.fromStream(
        name: fileName,
        size: size,
        openRead: entity.openRead,
        mimeType: mimeType,
        relativePath: rel,
      ),
    );
  }

  return PickedFolder(name: folderName, files: files);
}

Future<bool> saveFolderToDirectory({
  required String targetPath,
  required String folderName,
  required List<FolderEntry> entries,
  required Future<Uint8List> Function(Attachment) getFileBytes,
}) async {
  final baseDir = Directory(
    '$targetPath/$folderName'.replaceAll('/', Platform.pathSeparator),
  );
  if (!await baseDir.exists()) {
    await baseDir.create(recursive: true);
  }

  const maxConcurrency = 6;
  var nextIndex = 0;
  Object? firstError;
  StackTrace? firstStack;

  Future<void> worker() async {
    while (true) {
      if (firstError != null) return;
      final index = nextIndex++;
      if (index >= entries.length) return;
      final entry = entries[index];
      try {
        final filePath = '${baseDir.path}/${entry.relativePath}'
            .replaceAll('/', Platform.pathSeparator);
        final file = File(filePath);
        final parent = file.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
        final bytes = await getFileBytes(entry.toAttachment());
        await file.writeAsBytes(bytes, flush: true);
      } on Object catch (e, st) {
        if (firstError == null) {
          firstError = e;
          firstStack = st;
        }
        return;
      }
    }
  }

  final workerCount =
      entries.length < maxConcurrency ? entries.length : maxConcurrency;
  if (workerCount > 0) {
    await Future.wait([for (var w = 0; w < workerCount; w++) worker()]);
  }

  if (firstError != null) {
    Error.throwWithStackTrace(firstError!, firstStack!);
  }
  return true;
}
