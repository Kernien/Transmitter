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

  /// Размер результата [encryptStream] для открытого текста длиной
  /// [plaintextLength] байт.
  int encryptedLength(int plaintextLength);

  /// Потоковое шифрование кусками для больших файлов: весь файл не держится
  /// в памяти целиком.
  Stream<Uint8List> encryptStream(Stream<List<int>> plaintext);

  /// Потоковая расшифровка: поддерживает как кусковой формат, так и прежний
  /// одноблочный. Бросает [DecryptionException], если любой кусок повреждён,
  /// переставлен или поток оборван.
  Stream<Uint8List> decryptStream(Stream<List<int>> ciphertext);
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
