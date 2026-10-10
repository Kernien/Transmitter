import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/cipher.dart';
import 'package:transmitter/core/crypto/vault_key_derivation.dart';

void main() {
  group('AesGcmCipher', () {
    final key = List<int>.generate(32, (i) => i);
    final cipher = AesGcmCipher(key);

    test('шифрует и расшифровывает', () async {
      final plain = utf8.encode('Привет, Transmitter!');
      final encrypted = await cipher.encrypt(plain);
      expect(encrypted, isNot(equals(plain)));
      expect(await cipher.decrypt(encrypted), plain);
    });

    test('каждое шифрование даёт разный результат (случайный nonce)', () async {
      final plain = utf8.encode('одинаковый текст');
      expect(await cipher.encrypt(plain), isNot(equals(await cipher.encrypt(plain))));
    });

    test('изменённые данные не расшифровываются', () async {
      final encrypted = await cipher.encrypt(utf8.encode('секрет'));
      encrypted[encrypted.length ~/ 2] ^= 0xFF;
      expect(() => cipher.decrypt(encrypted), throwsA(isA<DecryptionException>()));
    });

    test('чужой ключ не расшифровывает', () async {
      final encrypted = await cipher.encrypt(utf8.encode('секрет'));
      final other = AesGcmCipher(List<int>.filled(32, 7));
      expect(() => other.decrypt(encrypted), throwsA(isA<DecryptionException>()));
    });

    test('большие данные (в отдельном потоке) шифруются и проверяются', () async {
      final plain = List<int>.generate(AesGcmCipher.backgroundThreshold + 10, (i) => i % 256);
      final encrypted = await cipher.encrypt(plain);
      expect(await cipher.decrypt(encrypted), plain);

      encrypted[100] ^= 0xFF;
      expect(() => cipher.decrypt(encrypted), throwsA(isA<DecryptionException>()));
    });

    test('слишком короткие данные дают DecryptionException', () {
      expect(() => cipher.decrypt([1, 2, 3]), throwsA(isA<DecryptionException>()));
    });
  });

  group('VaultKeyDerivation', () {
    const derivation = VaultKeyDerivation();
    final secretA = List<int>.filled(32, 1);
    final secretB = List<int>.filled(32, 2);

    test('детерминирована: одинаковый секрет даёт одинаковые значения', () async {
      final a1 = await derivation.derive(secretA);
      final a2 = await derivation.derive(secretA);
      expect(a1.vaultId, a2.vaultId);
      expect(a1.encryptionKey, a2.encryptionKey);
    });

    test('разные секреты дают разные базы', () async {
      final a = await derivation.derive(secretA);
      final b = await derivation.derive(secretB);
      expect(a.vaultId, isNot(b.vaultId));
      expect(a.encryptionKey, isNot(equals(b.encryptionKey)));
    });

    test('vaultId — 32 hex-символа, ключ — 32 байта', () async {
      final s = await derivation.derive(secretA);
      expect(s.vaultId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(s.encryptionKey, hasLength(32));
    });
  });
}
