import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/board_signature.dart';
import 'package:transmitter/core/crypto/vault_key_derivation.dart';
import 'package:transmitter/core/errors/app_error.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/vault/reader_key.dart';
import 'package:transmitter/core/vault/reader_key_codec.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_codec.dart';

void main() {
  const derivation = VaultKeyDerivation();
  final secretA = List<int>.generate(32, (i) => i);
  final secretB = List<int>.generate(32, (i) => 255 - i);

  Future<BoardSigner> signerFor(List<int> secret) async =>
      BoardSigner.fromSeed(await derivation.boardSigningSeed(secret));

  group('подпись описи', () {
    test('ключ подписи одинаков на всех устройствах владельца', () async {
      final first = await signerFor(secretA);
      final second = await signerFor(secretA);
      expect(first.publicKey, second.publicKey);
      expect(first.publicKey, hasLength(32));
      expect((await signerFor(secretB)).publicKey, isNot(first.publicKey));
    });

    test('ключ подписи не совпадает с ключом шифрования', () async {
      final secrets = await derivation.derive(secretA);
      final seed = await derivation.boardSigningSeed(secretA);
      expect(seed, isNot(secrets.encryptionKey));
    });

    test('подпись проверяется, подделка — нет', () async {
      final signer = await signerFor(secretA);
      final data = [1, 2, 3, 4];
      final signature = await signer.sign(data);
      final verifier = BoardVerifier(signer.publicKey);

      expect(await verifier.verify(data, signature), isTrue);
      expect(await verifier.verify([1, 2, 3, 5], signature), isFalse);
      expect(
        await BoardVerifier((await signerFor(secretB)).publicKey)
            .verify(data, signature),
        isFalse,
        reason: 'подписано не этим владельцем',
      );
      expect(await verifier.verify(data, signature.sublist(1)), isFalse);
    });
  });

  group('ключ читателя', () {
    final key = ReaderKey(
      provider: CloudProviderId.dropbox,
      label: 'Рецепты',
      locator: 'https://www.dropbox.com/scl/fi/abc/b.bin?rlkey=xyz&dl=0',
      encryptionKey: List<int>.filled(32, 7),
      ownerPublicKey: List<int>.filled(32, 9),
    );
    const codec = ReaderKeyCodec();

    test('строка и обратно', () {
      final text = codec.encode(key);
      expect(text, startsWith('TRM1R.'));
      expect(ReaderKeyCodec.looksLikeReaderKey('  $text\n'), isTrue);
      expect(codec.decode(text), key);
    });

    test('ключ владельца — не ключ читателя, и наоборот', () {
      final ownerKey = const VaultKeyCodec().encode(
        VaultKey(
          secret: secretA,
          provider: CloudProviderId.dropbox,
          label: 'x',
        ),
      );
      expect(ReaderKeyCodec.looksLikeReaderKey(ownerKey), isFalse);
      expect(
        () => codec.decode(ownerKey),
        throwsA(
          isA<InvalidVaultKeyException>().having(
            (e) => e.code,
            'code',
            ErrorCode.keyNotTransmitter,
          ),
        ),
      );
      // Старые версии (только TRM1.) ключ читателя не примут за ключ базы.
      expect(
        () => const VaultKeyCodec().decode(codec.encode(key)),
        throwsA(isA<InvalidVaultKeyException>()),
      );
    });

    test('повреждённый ключ — понятная ошибка', () {
      expect(
        () => codec.decode('TRM1R.bm90LWpzb24'),
        throwsA(
          isA<InvalidVaultKeyException>().having(
            (e) => e.code,
            'code',
            ErrorCode.keyCorrupted,
          ),
        ),
      );
    });
  });
}
