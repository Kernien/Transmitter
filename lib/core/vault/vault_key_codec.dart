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
/// Формат:
/// - `TRM1.<base64url(JSON)>` — зашифрованная база (совместимо со всеми
///   прежними версиями приложения);
/// - `TRM2.<base64url(JSON)>` — база с признаком шифрования (`e: false` для
///   баз без шифрования; старые версии не примут её за зашифрованную).
class VaultKeyCodec {
  const VaultKeyCodec();

  static const String _prefixV1 = 'TRM1.';
  static const String _prefixV2 = 'TRM2.';
  static final RegExp _futureVersion = RegExp(r'^TRM\d+\.');

  String encode(VaultKey key) {
    final prefix = key.isEncrypted ? _prefixV1 : _prefixV2;
    return prefix +
        base64Url
            .encode(utf8.encode(jsonEncode(toJson(key))))
            .replaceAll('=', '');
  }

  /// Бросает [InvalidVaultKeyException], если строка не является ключом
  /// Transmitter, ключ от более новой версии или повреждён.
  VaultKey decode(String input) {
    final text = input.trim();
    final String encoded;
    if (text.startsWith(_prefixV1)) {
      encoded = text.substring(_prefixV1.length);
    } else if (text.startsWith(_prefixV2)) {
      encoded = text.substring(_prefixV2.length);
    } else if (_futureVersion.hasMatch(text)) {
      throw const InvalidVaultKeyException(ErrorCode.keyRequiresUpdate);
    } else {
      throw const InvalidVaultKeyException(ErrorCode.keyNotTransmitter);
    }
    try {
      final payload = base64Url.normalize(encoded);
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
    if (!key.isEncrypted) 'e': false,
  };

  VaultKey fromJson(Map<String, dynamic> json) {
    try {
      final encrypted = json['e'];
      if (encrypted != null && encrypted is! bool) {
        throw const FormatException('Invalid encryption flag');
      }
      return VaultKey(
        secret: base64Url.decode(base64Url.normalize(json['s'] as String)),
        provider: CloudProviderId.fromCode(json['p'] as String),
        label: (json['n'] as String?) ?? '',
        // В ключах до версии 0.2 лимита нет — действует прежний, 25 МБ.
        maxFileSize:
            (json['m'] as num?)?.toInt() ?? VaultKey.defaultMaxFileSize,
        isEncrypted: (encrypted as bool?) ?? true,
      );
    } catch (_) {
      throw const InvalidVaultKeyException(ErrorCode.keyCorrupted);
    }
  }
}
