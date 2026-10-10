import 'dart:typed_data';

import 'package:transmitter/core/files/file_transfer_service.dart';

/// Имитация диалогов выбора и сохранения файла.
class FakeFileTransferService implements FileTransferService {
  PickedFile? nextPick;
  Object? pickError;
  bool saveAccepted = true;
  final List<(String, Uint8List)> saved = [];
  int? lastMaxSize;

  @override
  Future<PickedFile?> pickFile({required int maxSize}) async {
    lastMaxSize = maxSize;
    if (pickError != null) throw pickError!;
    return nextPick;
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
}
