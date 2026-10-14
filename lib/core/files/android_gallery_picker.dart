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
  Future<PickedFile?> pickMedia({required int maxSize}) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>('pick', {
      'maxSize': maxSize,
    });
    return raw == null
        ? null
        : parse(Map<String, Object?>.from(raw), maxSize: maxSize);
  }

  /// Разбор ответа нативной части (вынесен для тестов). Файл больше лимита
  /// приходит без байтов — только с именем и размером.
  static PickedFile parse(Map<String, Object?> raw, {required int maxSize}) {
    final name = raw['name'] as String? ?? 'photo';
    final size = (raw['size'] as num?)?.toInt() ?? 0;
    final bytes = raw['bytes'] as Uint8List?;
    if (bytes == null || bytes.length > maxSize) {
      throw FileTooLargeException(bytes?.length ?? size, maxSize);
    }
    return PickedFile(
      name: name,
      bytes: bytes,
      mimeType:
          raw['mimeType'] as String? ??
          lookupMimeType(name, headerBytes: bytes.take(32).toList()),
    );
  }
}
