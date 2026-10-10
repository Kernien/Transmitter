import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_codec.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';

void main() {
  const codec = VaultKeyCodec();

  test('сгенерированный ключ имеет 32 случайных байта', () {
    final a = VaultKey.generate(provider: CloudProviderId.googleDrive, label: 'A');
    final b = VaultKey.generate(provider: CloudProviderId.googleDrive, label: 'A');
    expect(a.secret, hasLength(32));
    expect(a.sameVaultAs(b), isFalse);
  });

  test('кодек: encode → decode возвращает тот же ключ', () {
    final key = VaultKey.generate(provider: CloudProviderId.dropbox, label: 'Работа');
    final code = codec.encode(key);
    expect(code, startsWith('TRM1.'));
    expect(code, isNot(contains('=')));
    expect(codec.decode(code), key);
  });

  test('кодек: пробелы вокруг строки игнорируются', () {
    final key = VaultKey.generate(provider: CloudProviderId.googleDrive, label: '');
    expect(codec.decode('  ${codec.encode(key)}\n'), key);
  });

  test('кодек: мусор даёт FormatException', () {
    expect(() => codec.decode('hello'), throwsFormatException);
    expect(() => codec.decode('TRM1.!!!'), throwsFormatException);
    expect(() => codec.decode('TRM1.e30'), throwsFormatException); // "{}"
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
