import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/errors/app_error.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_codec.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';

void main() {
  const codec = VaultKeyCodec();

  test('сгенерированный ключ имеет 32 случайных байта', () {
    final a = VaultKey.generate(
      provider: CloudProviderId.googleDrive,
      label: 'A',
    );
    final b = VaultKey.generate(
      provider: CloudProviderId.googleDrive,
      label: 'A',
    );
    expect(a.secret, hasLength(32));
    expect(a.sameVaultAs(b), isFalse);
  });

  test('кодек: encode → decode возвращает тот же ключ', () {
    final key = VaultKey.generate(
      provider: CloudProviderId.dropbox,
      label: 'Работа',
    );
    final code = codec.encode(key);
    expect(code, startsWith('TRM1.'));
    expect(code, isNot(contains('=')));
    expect(codec.decode(code), key);
  });

  test('кодек: пробелы вокруг строки игнорируются', () {
    final key = VaultKey.generate(
      provider: CloudProviderId.googleDrive,
      label: '',
    );
    expect(codec.decode('  ${codec.encode(key)}\n'), key);
  });

  test('кодек: мусор даёт FormatException', () {
    expect(() => codec.decode('hello'), throwsFormatException);
    expect(() => codec.decode('TRM1.!!!'), throwsFormatException);
    expect(() => codec.decode('TRM1.e30'), throwsFormatException); // "{}"
  });

  group('база без шифрования и версии формата', () {
    test('зашифрованный ключ остаётся TRM1., без шифрования — TRM2.', () {
      final encrypted = VaultKey.generate(
        provider: CloudProviderId.dropbox,
        label: 'Секрет',
      );
      expect(encrypted.isEncrypted, isTrue);
      expect(codec.encode(encrypted), startsWith('TRM1.'));
      expect(codec.decode(codec.encode(encrypted)), encrypted);

      final plain = VaultKey.generate(
        provider: CloudProviderId.dropbox,
        label: 'Общая папка',
        isEncrypted: false,
      );
      expect(plain.isEncrypted, isFalse);
      final code = codec.encode(plain);
      expect(code, startsWith('TRM2.'));
      final decoded = codec.decode(code);
      expect(decoded.isEncrypted, isFalse);
      expect(decoded, plain);
      expect(decoded.sameVaultAs(encrypted), isFalse);
    });

    test('неизвестная будущая версия просит обновить приложение', () {
      expect(
        () => codec.decode('TRM3.e30'),
        throwsA(
          isA<InvalidVaultKeyException>().having(
            (e) => e.code,
            'code',
            ErrorCode.keyRequiresUpdate,
          ),
        ),
      );
    });
  });

  group('лимит размера файла', () {
    String encodeJson(Map<String, dynamic> json) =>
        'TRM1.${base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '')}';

    test('по умолчанию 25 МБ; выбранный лимит передаётся вместе с ключом', () {
      expect(
        VaultKey.generate(
          provider: CloudProviderId.dropbox,
          label: '',
        ).maxFileSize,
        VaultKey.defaultMaxFileSize,
      );
      final key = VaultKey.generate(
        provider: CloudProviderId.dropbox,
        label: 'Большие',
        maxFileSize: 100 * 1024 * 1024,
      );
      final decoded = codec.decode(codec.encode(key));
      expect(decoded.maxFileSize, 100 * 1024 * 1024);
      expect(decoded, key);
    });

    test('старый ключ без лимита читается с лимитом 25 МБ', () {
      final key = VaultKey.generate(
        provider: CloudProviderId.dropbox,
        label: 'Старый',
      );
      final decoded = codec.decode(encodeJson(codec.toJson(key)..remove('m')));
      expect(decoded.maxFileSize, VaultKey.defaultMaxFileSize);
      expect(decoded.sameVaultAs(key), isTrue);
    });

    test('лимит вне 1–100 МБ в ключе — ключ повреждён', () {
      final key = VaultKey.generate(
        provider: CloudProviderId.dropbox,
        label: '',
      );
      for (final bad in [0, 500 * 1024 * 1024]) {
        final code = encodeJson(codec.toJson(key)..['m'] = bad);
        expect(() => codec.decode(code), throwsFormatException);
      }
    });
  });

  test('хранилище ключей сохраняет и загружает список', () async {
    final store = VaultKeyStore(InMemoryKeyValueStore());
    expect(await store.loadAll(), isEmpty);
    final keys = [
      VaultKey.generate(provider: CloudProviderId.googleDrive, label: 'Дом'),
      VaultKey.generate(provider: CloudProviderId.dropbox, label: 'Работа'),
    ];
    await store.saveAll(keys);
    expect(await store.loadAll(), keys);
  });

  test('OneDrive убран: его код — неизвестное облако, не падение', () {
    expect(
      CloudProviderId.values.map((p) => p.code),
      isNot(contains('onedrive')),
    );
    expect(() => CloudProviderId.fromCode('onedrive'), throwsFormatException);
  });
}
