import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/persistence/blob_cache.dart';
import 'package:transmitter/core/persistence/file_blob_cache.dart';

void main() {
  group('attachmentCacheKey', () {
    test('сохраняет короткие ASCII-ключи', () {
      final key = attachmentCacheKey('123e4567-e89b-12d3-a456-426614174000');
      expect(key, 'att-123e4567-e89b-12d3-a456-426614174000.bin');
      expect(isAttachmentCacheKey(key), isTrue);
    });

    test('длинное имя файла на кириллице не превышает лимит файловой системы', () {
      // Имя файла из реальной ошибки пользователя:
      const longName =
          'Пример дополнительных пояснений по судебному делу (2).docx';
      final key = attachmentCacheKey(longName);

      // Имя ключа должно соответствовать шаблону вложений
      expect(isAttachmentCacheKey(key), isTrue);

      // Длина ключа не должна превышать безопасный лимит (например, 150 символов,
      // так как лимит NTFS/ext4 для одного компонента имени файла — 255 символов)
      expect(key.length, lessThanOrEqualTo(150));

      // Ключ должен быть детерминированным (одинаковым при повторном вызове)
      expect(attachmentCacheKey(longName), equals(key));

      // Другое имя должно давать другой ключ
      const otherName =
          'Пример дополнительных пояснений по судебному делу (3).docx';
      expect(attachmentCacheKey(otherName), isNot(equals(key)));
    });

    test('FileBlobCache успешно записывает и читает файл с длинным именем', () async {
      final dir = await Directory.systemTemp.createTemp('attachment_key_test');
      try {
        final cache = FileBlobCache(dir);
        const longName =
            'Пример дополнительных пояснений по судебному делу (2).docx';
        final key = attachmentCacheKey(longName);
        final data = [1, 2, 3, 4, 5];

        await cache.write(key, data);
        final readData = await cache.read(key);
        expect(readData, equals(data));
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
