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
    final size = entity.lengthSync();

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

    if (size > inMemoryThreshold) {
      files.add(
        PickedFile.fromStream(
          name: fileName,
          size: size,
          openRead: entity.openRead,
          mimeType: mimeType,
          relativePath: rel,
        ),
      );
      continue;
    }

    final bytes = await entity.readAsBytes();
    files.add(
      PickedFile(
        name: fileName,
        bytes: bytes,
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

  for (final entry in entries) {
    final filePath = '${baseDir.path}/${entry.relativePath}'
        .replaceAll('/', Platform.pathSeparator);
    final file = File(filePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final bytes = await getFileBytes(entry.toAttachment());
    await file.writeAsBytes(bytes, flush: true);
  }
  return true;
}
