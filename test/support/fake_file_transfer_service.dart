import 'dart:typed_data';

import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/domain/post.dart';

/// Имитация диалогов выбора и сохранения файла и папки.
class FakeFileTransferService implements FileTransferService {
  PickedFile? nextPick;
  List<PickedFile>? nextPicks;
  PickedFolder? nextPickedFolder;
  Object? pickError;
  bool saveAccepted = true;
  bool saveFolderAccepted = true;
  final List<(String, Uint8List)> saved = [];
  final List<(String, List<FolderEntry>)> savedFolders = [];
  int? lastMaxSize;

  @override
  Future<List<PickedFile>> pickFiles({required int maxSize}) async {
    lastMaxSize = maxSize;
    if (pickError != null) throw pickError!;
    if (nextPicks != null) return nextPicks!;
    return nextPick == null ? const [] : [nextPick!];
  }

  @override
  Future<PickedFolder?> pickFolder({required int maxSize}) async {
    lastMaxSize = maxSize;
    if (pickError != null) throw pickError!;
    return nextPickedFolder;
  }

  @override
  Future<PickedFolder?> readDirectory(String path, {required int maxSize}) async {
    lastMaxSize = maxSize;
    if (pickError != null) throw pickError!;
    return nextPickedFolder;
  }

  @override
  Future<PickedFile> readFile(XFile file, {required int maxSize}) async {
    final size = await file.length();
    if (size > maxSize) throw FileTooLargeException(size, maxSize);
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (!saveAccepted) return false;
    saved.add((fileName, bytes));
    return true;
  }

  @override
  Future<bool> saveFolder({
    required String folderName,
    required List<FolderEntry> entries,
    required Future<Uint8List> Function(Attachment) getFileBytes,
  }) async {
    if (!saveFolderAccepted) return false;
    savedFolders.add((folderName, entries));
    for (final entry in entries) {
      final bytes = await getFileBytes(entry.toAttachment());
      saved.add((entry.relativePath, bytes));
    }
    return true;
  }
}
