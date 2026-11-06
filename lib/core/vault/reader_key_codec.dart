import 'dart:convert';

import '../errors/app_error.dart';
import '../storage/cloud_provider_id.dart';
import 'reader_key.dart';
import 'vault_key_codec.dart';

/// Превращает [ReaderKey] в строку для QR-кода или копирования и обратно.
///
/// Формат: `TRM1R.<base64url(JSON)>` (зашифрованная доска) или
/// `TRM2R.<base64url(JSON)>` (доска без шифрования) — отличается от ключа
/// владельца (`TRM1.` / `TRM2.`), поэтому старые версии приложения не примут
/// его за ключ базы.
class ReaderKeyCodec {
  const ReaderKeyCodec();

  static const String prefix = 'TRM1R.';
  static const String _prefixV2 = 'TRM2R.';
  static final RegExp _anyReaderPrefix = RegExp(r'^TRM\d+R\.');

  /// Похожа ли строка на ключ читателя (без проверки содержимого).
  static bool looksLikeReaderKey(String input) =>
      _anyReaderPrefix.hasMatch(input.trim());

  String encode(ReaderKey key) {
    final head = key.isEncrypted ? prefix : _prefixV2;
    return head +
        base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'p': key.provider.code,
                  'n': key.label,
                  'u': key.locator,
                  if (key.isEncrypted) 'k': base64Url.encode(key.encryptionKey),
                  'o': base64Url.encode(key.ownerPublicKey),
                }),
              ),
            )
            .replaceAll('=', '');
  }

  /// Бросает [InvalidVaultKeyException], если строка не является ключом
  /// читателя, ключ от более новой версии или повреждён.
  ReaderKey decode(String input) {
    final text = input.trim();
    final String encoded;
    if (text.startsWith(prefix)) {
      encoded = text.substring(prefix.length);
    } else if (text.startsWith(_prefixV2)) {
      encoded = text.substring(_prefixV2.length);
    } else if (_anyReaderPrefix.hasMatch(text)) {
      throw const InvalidVaultKeyException(ErrorCode.keyRequiresUpdate);
    } else {
      throw const InvalidVaultKeyException(ErrorCode.keyNotTransmitter);
    }
    try {
      final payload = base64Url.normalize(encoded);
      final json = jsonDecode(
        utf8.decode(base64Url.decode(payload)),
      ) as Map<String, dynamic>;
      List<int> bytes(String field) =>
          base64Url.decode(base64Url.normalize(json[field] as String));
      final hasEncryptionKey = json['k'] != null;
      return ReaderKey(
        provider: CloudProviderId.fromCode(json['p'] as String),
        label: (json['n'] as String?) ?? '',
        locator: json['u'] as String,
        encryptionKey: hasEncryptionKey ? bytes('k') : const [],
        ownerPublicKey: bytes('o'),
      );
    } catch (_) {
      throw const InvalidVaultKeyException(ErrorCode.keyCorrupted);
    }
  }
}
