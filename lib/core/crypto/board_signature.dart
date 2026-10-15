import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Подпись описи публичной доски (Ed25519).
///
/// Подписывает владелец (ключ выводится из секрета базы, см.
/// `VaultKeyDerivation.boardSigningSeed`), проверяет читатель по открытому
/// ключу из ключа читателя. Так читатель видит, что опись записал владелец и
/// по дороге её никто не изменил.
class BoardSigner {
  BoardSigner._(this._keyPair, this.publicKey);

  static Future<BoardSigner> fromSeed(List<int> seed) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return BoardSigner._(keyPair, Uint8List.fromList(publicKey.bytes));
  }

  static final Ed25519 _algorithm = Ed25519();

  /// Длина подписи в байтах.
  static const int signatureLength = 64;

  final SimpleKeyPair _keyPair;

  /// Открытый ключ — передаётся читателям.
  final Uint8List publicKey;

  Future<Uint8List> sign(List<int> data) async => Uint8List.fromList(
    (await _algorithm.sign(data, keyPair: _keyPair)).bytes,
  );
}

class BoardVerifier {
  BoardVerifier(List<int> publicKey)
    : _publicKey = SimplePublicKey(publicKey, type: KeyPairType.ed25519);

  final SimplePublicKey _publicKey;

  Future<bool> verify(List<int> data, List<int> signature) async {
    if (signature.length != BoardSigner.signatureLength) return false;
    return BoardSigner._algorithm.verify(
      data,
      signature: Signature(signature, publicKey: _publicKey),
    );
  }
}
