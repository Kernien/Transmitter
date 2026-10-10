import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import 'file_transfer_service.dart';

/// Реализация через пакет file_picker (Android, Windows, Web).
class FilePickerTransferService implements FileTransferService {
  const FilePickerTransferService();

  @override
  Future<PickedFile?> pickFile({required int maxSize}) async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;

    final knownSize = file.lengthSync() ?? await file.length();
    if (knownSize != null && knownSize > maxSize) {
      throw FileTooLargeException(knownSize, maxSize);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxSize) throw FileTooLargeException(bytes.length, maxSize);

    return PickedFile(
      name: file.name,
      bytes: bytes,
      mimeType: lookupMimeType(file.name, headerBytes: bytes.take(32).toList()),
    );
  }

  @override
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final saved = await FilePicker.saveFile(
      // В вебе file_picker требует расширение в имени файла.
      fileName: fileName.contains('.') ? fileName : '$fileName.bin',
      bytes: bytes,
      mimeType: mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream',
      dialogTitle: 'Сохранить файл',
    );
    return saved != null;
  }
}
