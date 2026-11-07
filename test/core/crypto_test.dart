import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart'
    show AesGcm, SecretBox, SecretKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/cipher.dart';
import 'package:transmitter/core/crypto/plaintext_cipher.dart';
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
      expect(
        await cipher.encrypt(plain),
        isNot(equals(await cipher.encrypt(plain))),
      );
    });

    test('изменённые данные не расшифровываются', () async {
      final encrypted = await cipher.encrypt(utf8.encode('секрет'));
      encrypted[encrypted.length ~/ 2] ^= 0xFF;
      expect(
        () => cipher.decrypt(encrypted),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('чужой ключ не расшифровывает', () async {
      final encrypted = await cipher.encrypt(utf8.encode('секрет'));
      final other = AesGcmCipher(List<int>.filled(32, 7));
      expect(
        () => other.decrypt(encrypted),
        throwsA(isA<DecryptionException>()),
      );
    });

    test(
      'большие данные (в отдельном потоке) шифруются и проверяются',
      () async {
        final plain = List<int>.generate(
          AesGcmCipher.backgroundThreshold + 10,
          (i) => i % 256,
        );
        final encrypted = await cipher.encrypt(plain);
        expect(await cipher.decrypt(encrypted), plain);

        encrypted[100] ^= 0xFF;
        expect(
          () => cipher.decrypt(encrypted),
          throwsA(isA<DecryptionException>()),
        );
      },
    );

    // Формат не изменился при переходе с пакета cryptography на webcrypto:
    // данные пользователей, зашифрованные раньше, читаются, и наоборот.
    test('совместим с прежней реализацией (cryptography)', () async {
      final legacy = AesGcm.with256bits();
      final plain = utf8.encode('старая запись');
      final old = await legacy.encrypt(plain, secretKey: SecretKey(key));
      expect(await cipher.decrypt(old.concatenation()), plain);

      final fresh = await cipher.encrypt(plain);
      final box = SecretBox.fromConcatenation(
        fresh,
        nonceLength: 12,
        macLength: 16,
      );
      expect(await legacy.decrypt(box, secretKey: SecretKey(key)), plain);
    });

    test('слишком короткие данные дают DecryptionException', () {
      expect(
        () => cipher.decrypt([1, 2, 3]),
        throwsA(isA<DecryptionException>()),
      );
    });

    group('потоковое шифрование кусками (TRMC v2)', () {
      final chunked = AesGcmCipher(key, chunkSize: 64);

      Future<Uint8List> collect(Stream<Uint8List> stream) async {
        final b = BytesBuilder(copy: false);
        await for (final part in stream) {
          b.add(part);
        }
        return b.takeBytes();
      }

      Stream<List<int>> sliceStream(Uint8List data, int step) async* {
        for (var i = 0; i < data.length; i += step) {
          final end = (i + step < data.length) ? i + step : data.length;
          yield Uint8List.sublistView(data, i, end);
        }
      }

      test('пустой, одноблочный, граничный и многокусковой потоки', () async {
        for (final size in [0, 1, 63, 64, 65, 128, 129, 300]) {
          final plain = Uint8List.fromList(
            List<int>.generate(size, (i) => (i * 13 + 7) & 0xff),
          );
          final encrypted = await collect(
            chunked.encryptStream(sliceStream(plain, 17)),
          );
          expect(encrypted.length, chunked.encryptedLength(size));
          // Потоковая расшифровка произвольными порциями:
          final decryptedStream = await collect(
            chunked.decryptStream(sliceStream(encrypted, 19)),
          );
          expect(decryptedStream, plain);
          // И обычная decrypt() понимает формат v2:
          expect(await chunked.decrypt(encrypted), plain);
        }
      });

      test('decryptStream понимает и прежний формат v1', () async {
        final plain = Uint8List.fromList(utf8.encode('старый формат v1'));
        final v1 = await cipher.encrypt(plain);
        final out = await collect(cipher.decryptStream(sliceStream(v1, 5)));
        expect(out, plain);
      });

      test('повреждение, обрыв или перестановка кусков → DecryptionException', () async {
        final plain = Uint8List.fromList(List<int>.generate(200, (i) => i));
        final encrypted = await collect(
          chunked.encryptStream(Stream.value(plain)),
        );

        // Испорченный байт внутри второго куска.
        final corrupted = Uint8List.fromList(encrypted);
        corrupted[24 + 80 + 10] ^= 0xff;
        await expectLater(
          collect(chunked.decryptStream(Stream.value(corrupted))),
          throwsA(isA<DecryptionException>()),
        );

        // Обрезанный поток (без последнего куска — первого куска нет флага isLast).
        final truncated = Uint8List.sublistView(encrypted, 0, 24 + 80);
        await expectLater(
          collect(chunked.decryptStream(Stream.value(truncated))),
          throwsA(isA<DecryptionException>()),
        );
        await expectLater(
          chunked.decrypt(truncated),
          throwsA(isA<DecryptionException>()),
        );

        // Перестановка кусков 0 и 1 местами.
        final swapped = Uint8List.fromList(encrypted);
        final c0 = encrypted.sublist(24, 24 + 80);
        final c1 = encrypted.sublist(24 + 80, 24 + 160);
        swapped.setRange(24, 24 + 80, c1);
        swapped.setRange(24 + 80, 24 + 160, c0);
        await expectLater(
          collect(chunked.decryptStream(Stream.value(swapped))),
          throwsA(isA<DecryptionException>()),
        );
      });

      test('PlaintextCipher пропускает поток без изменений', () async {
        const plainCipher = PlaintextCipher();
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(plainCipher.encryptedLength(data.length), data.length);
        final enc = await collect(
          plainCipher.encryptStream(Stream.value(data)),
        );
        expect(enc, data);
        final dec = await collect(plainCipher.decryptStream(Stream.value(enc)));
        expect(dec, data);
      });
    });
  });

  group('VaultKeyDerivation', () {
    const derivation = VaultKeyDerivation();
    final secretA = List<int>.filled(32, 1);
    final secretB = List<int>.filled(32, 2);

    test(
      'детерминирована: одинаковый секрет даёт одинаковые значения',
      () async {
        final a1 = await derivation.derive(secretA);
        final a2 = await derivation.derive(secretA);
        expect(a1.vaultId, a2.vaultId);
        expect(a1.encryptionKey, a2.encryptionKey);
      },
    );

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
