import 'dart:convert';

import '../errors/app_error.dart';
import '../storage/cloud_provider_id.dart';
import 'reader_key.dart';
import 'vault_key_codec.dart';

/// Превращает [ReaderKey] в строку для QR-кода или копирования и обратно.
///
/// Формат: `TRM1R.<base64url(JSON)>` — отличается от ключа владельца
/// (`TRM1.`), поэтому старые версии приложения не примут его за ключ базы.
class ReaderKeyCodec {
  const ReaderKeyCodec();

  static const String prefix = 'TRM1R.';

  /// Похожа ли строка на ключ читателя (без проверки содержимого).
  static bool looksLikeReaderKey(String input) =>
      input.trim().startsWith(prefix);

  String encode(ReaderKey key) =>
      prefix +
      base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'p': key.provider.code,
                'n': key.label,
                'u': key.locator,
                'k': base64Url.encode(key.encryptionKey),
                'o': base64Url.encode(key.ownerPublicKey),
              }),
            ),
          )
          .replaceAll('=', '');

  /// Бросает [InvalidVaultKeyException], если строка не является ключом
  /// читателя или ключ повреждён.
  ReaderKey decode(String input) {
    final text = input.trim();
    if (!text.startsWith(prefix)) {
      throw const InvalidVaultKeyException(ErrorCode.keyNotTransmitter);
    }
    try {
      final payload = base64Url.normalize(text.substring(prefix.length));
      final json = jsonDecode(
        utf8.decode(base64Url.decode(payload)),
      ) as Map<String, dynamic>;
      List<int> bytes(String field) =>
          base64Url.decode(base64Url.normalize(json[field] as String));
      return ReaderKey(
        provider: CloudProviderId.fromCode(json['p'] as String),
        label: (json['n'] as String?) ?? '',
        locator: json['u'] as String,
        encryptionKey: bytes('k'),
        ownerPublicKey: bytes('o'),
      );
    } catch (_) {
      throw const InvalidVaultKeyException(ErrorCode.keyCorrupted);
    }
  }
}
