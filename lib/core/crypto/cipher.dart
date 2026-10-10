import 'dart:typed_data';

/// Симметричное шифрование с проверкой целостности (AEAD).
///
/// Остальной код зависит только от этого интерфейса, поэтому алгоритм
/// можно заменить, не трогая репозитории и UI.
abstract interface class Cipher {
  Future<Uint8List> encrypt(List<int> plaintext);

  /// Бросает [DecryptionException], если данные повреждены или ключ неверный.
  Future<Uint8List> decrypt(List<int> ciphertext);
}

class DecryptionException implements Exception {
  const DecryptionException([this.message = 'Не удалось расшифровать данные']);

  final String message;

  @override
  String toString() => 'DecryptionException: $message';
}
