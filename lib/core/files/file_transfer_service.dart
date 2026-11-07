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
  const PickedFile({
    required this.name,
    required Uint8List bytes,
    this.mimeType,
  }) : _bytes = bytes,
       _openRead = null,
       size = bytes.length;

  /// Крупный файл, содержимое которого читается потоком с диска без загрузки
  /// целиком в оперативную память.
  const PickedFile.fromStream({
    required this.name,
    required this.size,
    required Stream<List<int>> Function() openRead,
    this.mimeType,
  }) : _bytes = null,
       // ignore: prefer_initializing_formals
       _openRead = openRead;

  /// Файл больше допустимого лимита: его байты не читались в память,
  /// чтобы остальные выбранные файлы всё равно ушли, а для этого была
  /// показана понятная ошибка с именем файла.
  const PickedFile.tooLarge({
    required this.name,
    required this.size,
    this.mimeType,
  }) : _bytes = null,
       _openRead = null;

  final String name;
  final int size;
  final Uint8List? _bytes;
  final Stream<List<int>> Function()? _openRead;
  final String? mimeType;

  /// Превысил ли файл лимит размера (байты не читались в память).
  bool get isTooLarge => _bytes == null && _openRead == null;

  /// Находятся ли все байты файла уже в памяти.
  bool get hasBytesInMemory => _bytes != null;

  Uint8List get bytes => _bytes!;

  /// Поток содержимого файла.
  Stream<List<int>> openRead() =>
      _openRead != null ? _openRead() : Stream<List<int>>.value(_bytes!);
}

/// Выбор файлов на устройстве и сохранение полученного файла.
abstract interface class FileTransferService {
  /// Показывает диалог выбора одного или нескольких файлов.
  /// Пустой список, если пользователь отменил выбор.
  /// Если выбран один файл больше [maxSize], бросает `FileTooLargeException`
  /// (не читая его в память); при выборе нескольких такие файлы помечаются
  /// как [PickedFile.tooLarge].
  Future<List<PickedFile>> pickFiles({required int maxSize});

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
