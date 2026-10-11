import 'dart:convert';

import '../errors/app_error.dart';
import '../storage/cloud_provider_id.dart';
import 'vault_key.dart';

/// Строка не является ключом Transmitter ([ErrorCode.keyNotTransmitter])
/// или ключ повреждён ([ErrorCode.keyCorrupted]).
class InvalidVaultKeyException extends FormatException implements CodedError {
  const InvalidVaultKeyException(this.code) : super('Invalid Transmitter key');

  @override
  final ErrorCode code;

  @override
  Map<String, Object> get args => const {};
}

/// Превращает [VaultKey] в строку для QR-кода или копирования и обратно.
///
/// Формат: `TRM1.<base64url(JSON)>`. Номер версии в префиксе позволит
/// позже поменять формат, не ломая старые ключи.
class VaultKeyCodec {
  const VaultKeyCodec();

  static const String _prefix = 'TRM1.';

  String encode(VaultKey key) =>
      _prefix +
      base64Url
          .encode(utf8.encode(jsonEncode(toJson(key))))
          .replaceAll('=', '');

  /// Бросает [InvalidVaultKeyException], если строка не является ключом
  /// Transmitter или ключ повреждён.
  VaultKey decode(String input) {
    final text = input.trim();
    if (!text.startsWith(_prefix)) {
      throw const InvalidVaultKeyException(ErrorCode.keyNotTransmitter);
    }
    try {
      final payload = base64Url.normalize(text.substring(_prefix.length));
      final json = jsonDecode(utf8.decode(base64Url.decode(payload)));
      return fromJson(json as Map<String, dynamic>);
    } on InvalidVaultKeyException {
      rethrow;
    } catch (_) {
      throw const InvalidVaultKeyException(ErrorCode.keyCorrupted);
    }
  }

  Map<String, dynamic> toJson(VaultKey key) => {
    's': base64Url.encode(key.secret),
    'p': key.provider.code,
    'n': key.label,
    'm': key.maxFileSize,
  };

  VaultKey fromJson(Map<String, dynamic> json) {
    try {
      return VaultKey(
        secret: base64Url.decode(base64Url.normalize(json['s'] as String)),
        provider: CloudProviderId.fromCode(json['p'] as String),
        label: (json['n'] as String?) ?? '',
        // В ключах до версии 0.2 лимита нет — действует прежний, 25 МБ.
        maxFileSize:
            (json['m'] as num?)?.toInt() ?? VaultKey.defaultMaxFileSize,
      );
    } catch (_) {
      throw const InvalidVaultKeyException(ErrorCode.keyCorrupted);
    }
  }
}
