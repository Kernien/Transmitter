import 'dart:typed_data';

import 'package:cryptography/cryptography.dart'
    show AesGcm, SecretBox, SecretBoxAuthenticationError, SecretKey;

import 'cipher.dart';

/// AES-256-GCM. Формат результата: nonce (12 байт) | шифротекст | MAC (16 байт).
class AesGcmCipher implements Cipher {
  AesGcmCipher(List<int> keyBytes) : _key = SecretKey(List<int>.of(keyBytes)) {
    if (keyBytes.length != keyLength) {
      throw ArgumentError('Ключ AES-256 должен быть $keyLength байта');
    }
  }

  static const int keyLength = 32;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  static final AesGcm _algorithm = AesGcm.with256bits();

  final SecretKey _key;

  @override
  Future<Uint8List> encrypt(List<int> plaintext) async {
    final box = await _algorithm.encrypt(plaintext, secretKey: _key);
    return Uint8List.fromList(box.concatenation());
  }

  @override
  Future<Uint8List> decrypt(List<int> ciphertext) async {
    if (ciphertext.length < _nonceLength + _macLength) {
      throw const DecryptionException('Данные повреждены');
    }
    final box = SecretBox.fromConcatenation(
      ciphertext,
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    try {
      return Uint8List.fromList(await _algorithm.decrypt(box, secretKey: _key));
    } on SecretBoxAuthenticationError {
      throw const DecryptionException();
    }
  }
}
