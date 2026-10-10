import 'dart:convert';

import '../storage/cloud_provider_id.dart';
import 'vault_key.dart';

/// Превращает [VaultKey] в строку для QR-кода или копирования и обратно.
///
/// Формат: `TRM1.<base64url(JSON)>`. Номер версии в префиксе позволит
/// позже поменять формат, не ломая старые ключи.
class VaultKeyCodec {
  const VaultKeyCodec();

  static const String _prefix = 'TRM1.';

  String encode(VaultKey key) =>
      _prefix + base64Url.encode(utf8.encode(jsonEncode(toJson(key)))).replaceAll('=', '');

  /// Бросает [FormatException], если строка не является ключом Transmitter.
  VaultKey decode(String input) {
    final text = input.trim();
    if (!text.startsWith(_prefix)) {
      throw const FormatException('Это не ключ Transmitter');
    }
    try {
      final payload = base64Url.normalize(text.substring(_prefix.length));
      final json = jsonDecode(utf8.decode(base64Url.decode(payload)));
      return fromJson(json as Map<String, dynamic>);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Ключ повреждён');
    }
  }

  Map<String, dynamic> toJson(VaultKey key) => {
        's': base64Url.encode(key.secret),
        'p': key.provider.code,
        'n': key.label,
      };

  VaultKey fromJson(Map<String, dynamic> json) {
    try {
      return VaultKey(
        secret: base64Url.decode(base64Url.normalize(json['s'] as String)),
        provider: CloudProviderId.fromCode(json['p'] as String),
        label: (json['n'] as String?) ?? '',
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Ключ повреждён');
    }
  }
}
