import 'dart:typed_data';

import '../../../domain/post.dart';
import '../file_transfer_service.dart';

bool get isDirectorySupported => false;

Future<PickedFolder?> readDirectoryFromPath(
  String path, {
  required int maxSize,
  required int inMemoryThreshold,
}) async => null;

Future<bool> saveFolderToDirectory({
  required String targetPath,
  required String folderName,
  required List<FolderEntry> entries,
  required Future<Uint8List> Function(Attachment) getFileBytes,
}) async => false;
