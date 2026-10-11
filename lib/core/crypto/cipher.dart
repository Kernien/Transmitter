import 'dart:typed_data';

import '../errors/app_error.dart';

/// Симметричное шифрование с проверкой целостности (AEAD).
///
/// Остальной код зависит только от этого интерфейса, поэтому алгоритм
/// можно заменить, не трогая репозитории и UI.
abstract interface class Cipher {
  Future<Uint8List> encrypt(List<int> plaintext);

  /// Бросает [DecryptionException], если данные повреждены или ключ неверный.
  Future<Uint8List> decrypt(List<int> ciphertext);
}

/// Данные повреждены или зашифрованы другим ключом.
class DecryptionException implements Exception, CodedError {
  const DecryptionException([this.detail = '']);

  /// Техническая подробность для журналов.
  final String detail;

  @override
  ErrorCode get code => ErrorCode.decryptionFailed;

  @override
  Map<String, Object> get args => const {};

  @override
  String toString() => 'DecryptionException $detail'.trim();
}
