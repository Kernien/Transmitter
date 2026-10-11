import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import 'file_transfer_service.dart';

/// Реализация через пакет file_picker (Android, Windows, Web).
class FilePickerTransferService implements FileTransferService {
  const FilePickerTransferService({this.saveDialogTitle = _englishSaveTitle});

  /// Заголовок диалога сохранения на текущем языке интерфейса.
  final String Function() saveDialogTitle;

  static String _englishSaveTitle() => 'Save file';

  @override
  Future<PickedFile?> pickFile({required int maxSize}) async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;

    final knownSize = file.lengthSync() ?? await file.length();
    if (knownSize != null && knownSize > maxSize) {
      throw FileTooLargeException(knownSize, maxSize);
    }
    return _toPicked(file.name, await file.readAsBytes(), maxSize);
  }

  @override
  Future<PickedFile> readFile(XFile file, {required int maxSize}) async {
    final size = await file.length();
    if (size > maxSize) throw FileTooLargeException(size, maxSize);
    return _toPicked(
      file.name,
      await file.readAsBytes(),
      maxSize,
      mimeType: file.mimeType,
    );
  }

  static PickedFile _toPicked(
    String name,
    Uint8List bytes,
    int maxSize, {
    String? mimeType,
  }) {
    if (bytes.length > maxSize) {
      throw FileTooLargeException(bytes.length, maxSize);
    }
    return PickedFile(
      name: name,
      bytes: bytes,
      mimeType:
          mimeType ??
          lookupMimeType(name, headerBytes: bytes.take(32).toList()),
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
      mimeType:
          mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream',
      dialogTitle: saveDialogTitle(),
    );
    return saved != null;
  }
}
