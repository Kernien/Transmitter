import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import '../errors/app_error.dart';

export 'package:cross_file/cross_file.dart' show XFile;

class FileTooLargeException implements Exception, CodedError {
  const FileTooLargeException(this.size, this.maxSize);

  final int size;
  final int maxSize;

  @override
  ErrorCode get code => ErrorCode.fileTooLarge;

  @override
  Map<String, Object> get args => {'maxBytes': maxSize};

  @override
  String toString() => describeForLog(this);
}

/// Файл, выбранный пользователем для отправки.
class PickedFile {
  const PickedFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;
}

/// Выбор файла на устройстве и сохранение полученного файла.
abstract interface class FileTransferService {
  /// Показывает диалог выбора файла. `null`, если пользователь отменил выбор.
  /// Бросает `FileTooLargeException`, если файл больше [maxSize]; в этом
  /// случае файл не читается в память.
  Future<PickedFile?> pickFile({required int maxSize});

  /// Читает уже выбранный файл (например, перетащенный в окно) с той же
  /// проверкой размера, что и [pickFile].
  Future<PickedFile> readFile(XFile file, {required int maxSize});

  /// Сохраняет файл: диалог «Сохранить как» на компьютере и телефоне,
  /// обычное скачивание в браузере. `false`, если пользователь отменил.
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  });
}
