import 'package:flutter/foundation.dart';
import 'package:webcrypto/webcrypto.dart'
    show AesGcmSecretKey, OperationError, fillRandomBytes;

import 'cipher.dart';

/// AES-256-GCM. Формат результата: nonce (12 байт) | шифротекст | MAC (16 байт).
///
/// На устройствах — BoringSSL (webcrypto, аппаратный AES: сотни МБ/с), в
/// вебе — WebCrypto браузера. Большие данные (файлы) обрабатываются в
/// отдельном потоке, чтобы интерфейс не замирал даже на долю секунды.
///
/// Для `flutter test` нативную библиотеку нужно один раз собрать:
/// `dart run webcrypto:setup` (см. docs/DEVELOPMENT.md).
class AesGcmCipher implements Cipher {
  AesGcmCipher(List<int> keyBytes) : _keyBytes = Uint8List.fromList(keyBytes) {
    if (keyBytes.length != keyLength) {
      throw ArgumentError('AES-256 key must be $keyLength bytes');
    }
  }

  static const int keyLength = 32;

  /// С какого размера данные обрабатываются в отдельном потоке.
  static const int backgroundThreshold = 4 * 1024 * 1024;

  final Uint8List _keyBytes;

  static bool _inBackground(List<int> data) =>
      !kIsWeb && data.length >= backgroundThreshold;

  // Ключ импортируется при каждом вызове: это дёшево, а общий Future
  // нельзя делить между зонами (в тестах виджетов он зависает).
  Future<AesGcmSecretKey> get _secretKey =>
      AesGcmSecretKey.importRawKey(_keyBytes);

  @override
  Future<Uint8List> encrypt(List<int> plaintext) async =>
      _inBackground(plaintext)
      ? compute(_encryptJob, (_keyBytes, plaintext))
      : _encrypt(await _secretKey, plaintext);

  @override
  Future<Uint8List> decrypt(List<int> ciphertext) async =>
      _inBackground(ciphertext)
      ? compute(_decryptJob, (_keyBytes, ciphertext))
      : _decrypt(await _secretKey, ciphertext);
}

const int _nonceLength = 12;
const int _macLength = 16;

// Функции верхнего уровня: их можно передать в compute().
Future<Uint8List> _encryptJob((Uint8List, List<int>) args) async =>
    _encrypt(await AesGcmSecretKey.importRawKey(args.$1), args.$2);

Future<Uint8List> _decryptJob((Uint8List, List<int>) args) async =>
    _decrypt(await AesGcmSecretKey.importRawKey(args.$1), args.$2);

Future<Uint8List> _encrypt(AesGcmSecretKey key, List<int> plaintext) async {
  final nonce = Uint8List(_nonceLength);
  fillRandomBytes(nonce);
  // webcrypto возвращает шифротекст с MAC в конце — остаётся дописать nonce.
  final sealed = await key.encryptBytes(plaintext, nonce);
  return Uint8List(_nonceLength + sealed.length)
    ..setAll(0, nonce)
    ..setAll(_nonceLength, sealed);
}

Future<Uint8List> _decrypt(AesGcmSecretKey key, List<int> ciphertext) async {
  if (ciphertext.length < _nonceLength + _macLength) {
    throw const DecryptionException('ciphertext too short');
  }
  final bytes = ciphertext is Uint8List
      ? ciphertext
      : Uint8List.fromList(ciphertext);
  try {
    return await key.decryptBytes(
      Uint8List.sublistView(bytes, _nonceLength),
      Uint8List.sublistView(bytes, 0, _nonceLength),
    );
  } on OperationError {
    throw const DecryptionException();
  }
}
