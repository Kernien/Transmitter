import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/storage/providers/mega/mega_aes.dart';
import 'package:transmitter/core/storage/providers/mega/mega_crypto.dart';

/// Эталоны посчитаны встроенным crypto Node.js по логике megajs
/// (генератор — вне репозитория, значения — в mega_vectors.json).
final Map<String, dynamic> vectors = jsonDecode(
  File('test/core/mega_vectors.json').readAsStringSync(),
) as Map<String, dynamic>;

Uint8List unhex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List plainFor(int size) =>
    Uint8List.fromList([for (var i = 0; i < size; i++) (i * 31 + size) & 0xff]);

void main() {
  group('AES-128', () {
    test('вектор FIPS-197', () {
      final aes = MegaAes(unhex('000102030405060708090a0b0c0d0e0f'));
      final block = unhex('00112233445566778899aabbccddeeff');
      expect(hexOf(aes.encryptEcb(block)), '69c4e0d86a7b0430d8cdb78070b4c55a');
      expect(aes.decryptEcb(aes.encryptEcb(block)), block);
    });

    test('ECB и CBC с нулевым IV — как в Node.js', () {
      final v = vectors['aes'] as Map<String, dynamic>;
      final aes = MegaAes(unhex(v['key'] as String));
      final data = unhex(v['data'] as String);
      expect(hexOf(aes.encryptEcb(data)), v['ecb']);
      expect(hexOf(aes.encryptCbc(data)), v['cbc']);
      expect(aes.decryptEcb(unhex(v['ecb'] as String)), data);
      expect(aes.decryptCbc(unhex(v['cbc'] as String)), data);
    });
  });

  group('вход', () {
    test('аккаунт v2: PBKDF2-SHA512', () async {
      final v = vectors['v2'] as Map<String, dynamic>;
      final derived = await MegaCrypto.deriveV2(
        v['password'] as String,
        MegaCrypto.unb64(v['salt'] as String),
      );
      expect(hexOf(derived.passwordKey), v['passwordKey']);
      expect(derived.userHash, v['userHash']);
    });

    test('старый аккаунт v1: prepareKey и хеш почты', () {
      final v = vectors['v1'] as Map<String, dynamic>;
      final key = MegaCrypto.prepareKeyV1(utf8.encode(v['password'] as String));
      expect(hexOf(key), v['passwordKey']);
      expect(MegaCrypto.userHashV1(v['email'] as String, key), v['userHash']);
    });

    test('идентификатор сеанса расшифровывается RSA-ключом аккаунта', () {
      final v = vectors['session'] as Map<String, dynamic>;
      final sid = MegaCrypto.decryptSessionId(
        csid: MegaCrypto.unb64(v['csid'] as String),
        privk: MegaCrypto.unb64(v['privk'] as String),
        masterKey: unhex(v['masterKey'] as String),
      );
      expect(sid, v['sid']);
    });
  });

  group('файлы', () {
    test('куски MAC: 128 КБ, 256 КБ, … затем по 1 МБ', () {
      expect(MegaCrypto.chunkEnds(0), [0]);
      expect(MegaCrypto.chunkEnds(131072), [131072]);
      expect(MegaCrypto.chunkEnds(131073), [131072, 131073]);
      final ends = MegaCrypto.chunkEnds(10 * 1048576);
      expect(ends.take(8), [
        131072,
        393216,
        786432,
        1310720,
        1966080,
        2752512,
        3670016,
        4718592,
      ]);
      expect(ends[8], 4718592 + 1048576);
      expect(ends.last, 10 * 1048576);
    });

    for (final f in (vectors['files'] as List).cast<Map<String, dynamic>>()) {
      test('шифрование и MAC, ${f['size']} байт', () {
        final plain = plainFor(f['size'] as int);
        expect(sha256.convert(plain).toString(), f['plainSha']);
        final key = unhex(f['key'] as String);
        final nonce = unhex(f['nonce'] as String);
        final encrypted = MegaCrypto.encryptFile(plain, key, nonce);
        expect(sha256.convert(encrypted.data).toString(), f['dataSha']);
        expect(hexOf(encrypted.mac), f['mac']);
        expect(
          MegaCrypto.decryptFile(encrypted.data, key, nonce, encrypted.mac),
          plain,
        );
      });
    }

    test('испорченный файл не проходит проверку MAC', () {
      final plain = plainFor(1000);
      final key = MegaCrypto.randomBytes(16);
      final nonce = MegaCrypto.randomBytes(8);
      final encrypted = MegaCrypto.encryptFile(plain, key, nonce);
      encrypted.data[500] ^= 1;
      expect(
        MegaCrypto.decryptFile(encrypted.data, key, nonce, encrypted.mac),
        isNull,
      );
    });

    test('ключ узла файла: ключ AES ⊕ (nonce, MAC) и обратно', () {
      final key = MegaCrypto.randomBytes(16);
      final nonce = MegaCrypto.randomBytes(8);
      final mac = MegaCrypto.randomBytes(8);
      final packed = MegaCrypto.packFileKey(key, nonce, mac);
      expect(packed.length, 32);
      expect(MegaCrypto.fileAesKey(packed), key);
      expect(packed.sublist(16, 24), nonce);
      expect(packed.sublist(24), mac);
    });
  });

  test('атрибуты узла: «MEGA{json}» в AES-CBC', () {
    final v = vectors['attributes'] as Map<String, dynamic>;
    final key = unhex(v['key'] as String);
    expect(MegaCrypto.encryptAttributes({'n': v['name']}, key), v['encrypted']);
    expect(
      MegaCrypto.decryptAttributes(v['encrypted'] as String, key)?['n'],
      v['name'],
    );
    // Чужой ключ — не атрибуты.
    expect(
      MegaCrypto.decryptAttributes(
        v['encrypted'] as String,
        MegaCrypto.randomBytes(16),
      ),
      isNull,
    );
  });

  test('hashcash: ответ проходит порог сложности', () async {
    final token = MegaCrypto.b64(List.filled(48, 7));
    // Сложность 255 — порог около половины значений, решается быстро.
    final answer = await MegaCrypto.solveHashcash('1:255:1700000000:$token');
    final parts = answer.split(':');
    expect(parts[0], '1');
    expect(parts[1], token);
    final prefix = MegaCrypto.unb64(parts[2]);
    final buffer = Uint8List(4 + 262144 * 48)..setRange(0, 4, prefix);
    for (var i = 0; i < 262144; i++) {
      buffer.fillRange(4 + i * 48, 4 + (i + 1) * 48, 7);
    }
    final hash = sha256.convert(buffer).bytes;
    final value = (hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3];
    expect(value, lessThanOrEqualTo(127 << 24));
  });
}
