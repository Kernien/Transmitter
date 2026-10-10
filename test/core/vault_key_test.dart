import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
      VaultKey.generate(provider: CloudProviderId.oneDrive, label: 'Работа'),
    ];
    await store.saveAll(keys);
    expect(await store.loadAll(), keys);
  });
}
