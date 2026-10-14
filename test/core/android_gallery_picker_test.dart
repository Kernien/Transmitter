import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/files/android_gallery_picker.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';

void main() {
  final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);

  test('фото из Галереи: имя, тип и байты', () {
    final file = AndroidGalleryPicker.parse({
      'name': 'IMG_0001.jpg',
      'mimeType': 'image/jpeg',
      'size': bytes.length,
      'bytes': bytes,
    }, maxSize: 100);
    expect(file.name, 'IMG_0001.jpg');
    expect(file.mimeType, 'image/jpeg');
    expect(file.bytes, bytes);
  });

  test('без MIME-типа — определяется по имени', () {
    final file = AndroidGalleryPicker.parse({
      'name': 'VID_0002.mp4',
      'bytes': Uint8List.fromList([1, 2, 3]),
    }, maxSize: 100);
    expect(file.mimeType, 'video/mp4');
  });

  test('слишком большой файл приходит без байтов — понятная ошибка', () {
    expect(
      () => AndroidGalleryPicker.parse({
        'name': 'VID_0003.mp4',
        'size': 300 << 20,
        'bytes': null,
      }, maxSize: 25 << 20),
      throwsA(
        isA<FileTooLargeException>()
            .having((e) => e.size, 'size', 300 << 20)
            .having((e) => e.maxSize, 'maxSize', 25 << 20),
      ),
    );
  });
}
