import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

import 'file_transfer_service.dart';
import 'media_picker.dart';

/// Галерея на Android. Нативная часть — GalleryPicker.kt.
class AndroidGalleryPicker implements MediaPicker {
  const AndroidGalleryPicker();

  static const MethodChannel _channel = MethodChannel(
    'app.transmitter/gallery',
  );

  @override
  bool get isAvailable => true;

  @override
  Future<List<PickedFile>> pickMedia({required int maxSize}) async {
    final raw = await _channel.invokeMethod<Object?>('pick', {
      'maxSize': maxSize,
    });
    if (raw == null) return const [];
    if (raw is List<Object?>) {
      return parseList(raw, maxSize: maxSize);
    }
    if (raw is Map<Object?, Object?>) {
      return [parse(Map<String, Object?>.from(raw), maxSize: maxSize)];
    }
    return const [];
  }

  /// Разбор списка файлов из нативной части. Если выбран один файл больше
  /// лимита — бросает [FileTooLargeException]; если несколько — слишком
  /// большие помечаются как [PickedFile.tooLarge], чтобы остальные ушли.
  static List<PickedFile> parseList(
    List<Object?> raw, {
    required int maxSize,
  }) {
    if (raw.isEmpty) return const [];
    if (raw.length == 1) {
      final single = Map<String, Object?>.from(raw.single! as Map);
      return [parse(single, maxSize: maxSize)];
    }
    return [
      for (final item in raw)
        _parseItem(
          Map<String, Object?>.from(item! as Map),
          maxSize: maxSize,
          throwOnTooLarge: false,
        ),
    ];
  }

  /// Разбор одного файла из ответа нативной части (вынесен для тестов).
  /// Файл больше лимита приходит без байтов — только с именем и размером.
  static PickedFile parse(Map<String, Object?> raw, {required int maxSize}) =>
      _parseItem(raw, maxSize: maxSize, throwOnTooLarge: true);

  static PickedFile _parseItem(
    Map<String, Object?> raw, {
    required int maxSize,
    required bool throwOnTooLarge,
  }) {
    final name = raw['name'] as String? ?? 'photo';
    final size = (raw['size'] as num?)?.toInt() ?? 0;
    final bytes = raw['bytes'] as Uint8List?;
    final declaredMime = raw['mimeType'] as String?;
    if (bytes == null || bytes.length > maxSize) {
      final actualSize = bytes?.length ?? size;
      if (throwOnTooLarge) {
        throw FileTooLargeException(actualSize, maxSize);
      }
      return PickedFile.tooLarge(
        name: name,
        size: actualSize,
        mimeType: declaredMime ?? lookupMimeType(name),
      );
    }
    return PickedFile(
      name: name,
      bytes: bytes,
      mimeType:
          declaredMime ??
          lookupMimeType(name, headerBytes: bytes.take(32).toList()),
    );
  }
}
