import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/utils/text_decoding.dart';
import 'package:transmitter/domain/post.dart';

void main() {
  group('кодировка текста', () {
    test('UTF-8 — с меткой и без', () {
      expect(decodeTextPreview(utf8.encode('Привет, мир')).text, 'Привет, мир');
      expect(
        decodeTextPreview([0xEF, 0xBB, 0xBF, ...utf8.encode('Да')]).text,
        'Да',
      );
    });

    test('Windows-1251 — русский текст из старого Блокнота', () {
      // «Ёлка №1 — «да»» в Windows-1251.
      final bytes = [
        0xA8, 0xEB, 0xEA, 0xE0, 0x20, 0xB9, 0x31, 0x20, 0x97, 0x20, //
        0xAB, 0xE4, 0xE0, 0xBB,
      ];
      expect(decodeTextPreview(bytes).text, 'Ёлка №1 — «да»');
    });

    test('UTF-16 с меткой порядка байтов', () {
      final le = [0xFF, 0xFE, 0x1F, 0x04, 0x40, 0x04]; // «Пр»
      final be = [0xFE, 0xFF, 0x04, 0x1F, 0x04, 0x40];
      expect(decodeTextPreview(le).text, 'Пр');
      expect(decodeTextPreview(be).text, 'Пр');
    });

    test('большой файл обрезается, не разрывая символ', () {
      final text = 'я' * 10; // по 2 байта на букву
      final preview = decodeTextPreview(utf8.encode(text), maxBytes: 5);
      expect(preview.truncated, isTrue);
      expect(preview.text, 'яя');
      expect(decodeTextPreview(utf8.encode(text)).truncated, isFalse);
    });
  });

  test('какие файлы читаются как текст', () {
    Attachment file(String name, [String? mime]) =>
        Attachment(id: 'a', fileName: name, size: 1, mimeType: mime);
    expect(file('заметки.TXT').isText, isTrue);
    expect(file('data.csv').isText, isTrue);
    expect(file('main.dart').isText, isTrue);
    expect(file('x', 'text/plain').isText, isTrue);
    expect(file('x', 'application/json').isText, isTrue);
    expect(file('фото.jpg', 'image/jpeg').isText, isFalse);
    expect(file('отчёт.pdf', 'application/pdf').isText, isFalse);
    expect(file('архив.zip').isText, isFalse);
  });
}
