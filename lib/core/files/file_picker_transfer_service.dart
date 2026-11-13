import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import '../../domain/post.dart';
import 'directory/platform_directory.dart' as platform_dir;
import 'file_transfer_service.dart';

/// Реализация через пакет file_picker (Android, Windows, Web).
class FilePickerTransferService implements FileTransferService {
  const FilePickerTransferService({this.saveDialogTitle = _englishSaveTitle});

  /// Файлы больше этого порога не загружаются в память целиком, а читаются
  /// потоком кусками при шифровании и отправке.
  static const int inMemoryThreshold = 16 * 1024 * 1024;

  /// Заголовок диалога сохранения на текущем языке интерфейса.
  final String Function() saveDialogTitle;

  static String _englishSaveTitle() => 'Save file';

  @override
  Future<List<PickedFile>> pickFiles({required int maxSize}) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return const [];

    final picked = <PickedFile>[];
    for (final file in files) {
      final knownSize = file.lengthSync() ?? await file.length();
      if (knownSize != null && knownSize > maxSize) {
        if (files.length == 1) {
          throw FileTooLargeException(knownSize, maxSize);
        }
        picked.add(
          PickedFile.tooLarge(
            name: file.name,
            size: knownSize,
            mimeType: lookupMimeType(file.name),
          ),
        );
        continue;
      }
      if (knownSize != null && knownSize > inMemoryThreshold) {
        final xFile = file.xFile;
        picked.add(
          PickedFile.fromStream(
            name: file.name,
            size: knownSize,
            openRead: xFile.openRead,
            mimeType: await _detectMime(xFile, knownSize),
          ),
        );
        continue;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > maxSize) {
        if (files.length == 1) {
          throw FileTooLargeException(bytes.length, maxSize);
        }
        picked.add(
          PickedFile.tooLarge(
            name: file.name,
            size: bytes.length,
            mimeType: lookupMimeType(file.name),
          ),
        );
        continue;
      }
      picked.add(_toPicked(file.name, bytes, maxSize));
    }
    return picked;
  }

  @override
  Future<PickedFolder?> pickFolder({required int maxSize}) async {
    if (!platform_dir.isDirectorySupported) return null;
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: saveDialogTitle(),
    );
    if (path == null) return null;
    return readDirectory(path, maxSize: maxSize);
  }

  @override
  Future<PickedFolder?> readDirectory(
    String path, {
    required int maxSize,
  }) => platform_dir.readDirectoryFromPath(
    path,
    maxSize: maxSize,
    inMemoryThreshold: inMemoryThreshold,
  );

  @override
  Future<PickedFile> readFile(XFile file, {required int maxSize}) async {
    final size = await file.length();
    if (size > maxSize) throw FileTooLargeException(size, maxSize);
    if (size > inMemoryThreshold) {
      return PickedFile.fromStream(
        name: file.name,
        size: size,
        openRead: file.openRead,
        mimeType: await _detectMime(file, size),
      );
    }
    return _toPicked(
      file.name,
      await file.readAsBytes(),
      maxSize,
      mimeType: file.mimeType,
    );
  }

  static Future<String?> _detectMime(XFile file, int size) async {
    if (file.mimeType != null && file.mimeType!.isNotEmpty) {
      return file.mimeType;
    }
    if (size <= 0) return lookupMimeType(file.name);
    final header = <int>[];
    final end = size < 32 ? size : 32;
    await for (final chunk in file.openRead(0, end)) {
      header.addAll(chunk);
      if (header.length >= 32) break;
    }
    return lookupMimeType(file.name, headerBytes: header);
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

  @override
  Future<bool> saveFolder({
    required String folderName,
    required List<FolderEntry> entries,
    required Future<Uint8List> Function(Attachment) getFileBytes,
  }) async {
    if (platform_dir.isDirectorySupported) {
      final targetPath = await FilePicker.getDirectoryPath(
        dialogTitle: saveDialogTitle(),
      );
      if (targetPath == null) return false;
      return platform_dir.saveFolderToDirectory(
        targetPath: targetPath,
        folderName: folderName,
        entries: entries,
        getFileBytes: getFileBytes,
      );
    }

    // В вебе или при отсутствии прямой файловой системы скачиваем zip-архив.
    final archive = Archive();
    for (final entry in entries) {
      final bytes = await getFileBytes(entry.toAttachment());
      archive.addFile(
        ArchiveFile(entry.relativePath, bytes.length, bytes),
      );
    }
    final zipData = ZipEncoder().encode(archive);
    final zipBytes = Uint8List.fromList(zipData);
    final zipName =
        folderName.toLowerCase().endsWith('.zip')
            ? folderName
            : '$folderName.zip';
    return saveFile(
      fileName: zipName,
      bytes: zipBytes,
      mimeType: 'application/zip',
    );
  }
}
