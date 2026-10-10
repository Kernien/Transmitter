import 'package:cryptography/cryptography.dart'
    show AesGcm, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:flutter/foundation.dart';

import 'cipher.dart';

/// AES-256-GCM. Формат результата: nonce (12 байт) | шифротекст | MAC (16 байт).
///
/// Большие данные (файлы) шифруются в отдельном потоке, чтобы не замирал
/// интерфейс: AES на чистом Dart обрабатывает около 10 МБ/с. В вебе это не
/// нужно — там работает WebCrypto браузера.
class AesGcmCipher implements Cipher {
  AesGcmCipher(List<int> keyBytes) : _keyBytes = Uint8List.fromList(keyBytes) {
    if (keyBytes.length != keyLength) {
      throw ArgumentError('Ключ AES-256 должен быть $keyLength байта');
    }
  }

  static const int keyLength = 32;

  /// С какого размера данные обрабатываются в отдельном потоке.
  static const int backgroundThreshold = 256 * 1024;

  final Uint8List _keyBytes;

  static bool _inBackground(List<int> data) =>
      !kIsWeb && data.length >= backgroundThreshold;

  @override
  Future<Uint8List> encrypt(List<int> plaintext) => _inBackground(plaintext)
      ? compute(_encryptJob, (_keyBytes, plaintext))
      : _encrypt(_keyBytes, plaintext);

  @override
  Future<Uint8List> decrypt(List<int> ciphertext) => _inBackground(ciphertext)
      ? compute(_decryptJob, (_keyBytes, ciphertext))
      : _decrypt(_keyBytes, ciphertext);
}

const int _nonceLength = 12;
const int _macLength = 16;
final AesGcm _algorithm = AesGcm.with256bits();

// Функции верхнего уровня: их можно передать в compute().
Future<Uint8List> _encryptJob((Uint8List, List<int>) args) =>
    _encrypt(args.$1, args.$2);

Future<Uint8List> _decryptJob((Uint8List, List<int>) args) =>
    _decrypt(args.$1, args.$2);

Future<Uint8List> _encrypt(Uint8List key, List<int> plaintext) async {
  final box = await _algorithm.encrypt(plaintext, secretKey: SecretKey(key));
  return Uint8List.fromList(box.concatenation());
}

Future<Uint8List> _decrypt(Uint8List key, List<int> ciphertext) async {
  if (ciphertext.length < _nonceLength + _macLength) {
    throw const DecryptionException('Данные повреждены');
  }
  final box = SecretBox.fromConcatenation(
    ciphertext,
    nonceLength: _nonceLength,
    macLength: _macLength,
  );
  try {
    return Uint8List.fromList(
      await _algorithm.decrypt(box, secretKey: SecretKey(key)),
    );
  } on SecretBoxAuthenticationError {
    throw const DecryptionException();
  }
}
