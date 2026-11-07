import 'dart:typed_data';

import 'cipher.dart';

/// Реализация [Cipher] без шифрования (для открытых баз).
///
/// Данные хранятся в облаке как есть — файлы и записи видны и открываются
/// прямо в облаке без приложения.
class PlaintextCipher implements Cipher {
  const PlaintextCipher();

  @override
  Future<Uint8List> encrypt(List<int> plaintext) async =>
      Uint8List.fromList(plaintext);

  @override
  Future<Uint8List> decrypt(List<int> ciphertext) async =>
      Uint8List.fromList(ciphertext);

  @override
  int encryptedLength(int plaintextLength) => plaintextLength;

  @override
  Stream<Uint8List> encryptStream(Stream<List<int>> plaintext) => plaintext.map(
    (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
  );

  @override
  Stream<Uint8List> decryptStream(Stream<List<int>> ciphertext) =>
      ciphertext.map(
        (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
      );
}
