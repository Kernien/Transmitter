import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'mega_crypto.dart';

/// Адрес файла для читателя публичной доски в MEGA: ссылка на папку и имя
/// файла в ней — `https://mega.nz/folder/<дескриптор>#<ключ папки>/<имя>`.
///
/// Ссылка на сам файл не годится: MEGA при перезаписи создаёт новый узел с
/// новой ссылкой, а опись доски перезаписывается при каждом изменении.
/// Ссылка на папку остаётся прежней, файл в ней ищется по имени.
class MegaFolderLink {
  const MegaFolderLink({
    required this.publicHandle,
    required this.shareKey,
    required this.fileName,
  });

  static const String _prefix = 'https://mega.nz/folder/';

  /// Публичный дескриптор папки (команда `l`).
  final String publicHandle;

  /// Общий ключ папки: им зашифрованы ключи файлов для читателя.
  final Uint8List shareKey;
  final String fileName;

  String encode() =>
      '$_prefix$publicHandle#${MegaCrypto.b64(shareKey)}/$fileName';

  /// `null` — не адрес MEGA.
  static MegaFolderLink? parse(String locator) {
    if (!locator.startsWith(_prefix)) return null;
    final rest = locator.substring(_prefix.length);
    final hash = rest.indexOf('#');
    final slash = rest.indexOf('/', hash + 1);
    if (hash <= 0 || slash < 0 || slash == rest.length - 1) return null;
    final Uint8List key;
    try {
      key = MegaCrypto.unb64(rest.substring(hash + 1, slash));
    } on FormatException {
      return null;
    }
    if (key.length != 16) return null;
    return MegaFolderLink(
      publicHandle: rest.substring(0, hash),
      shareKey: key,
      fileName: rest.substring(slash + 1),
    );
  }

  /// Общий ключ папки [folderHandle]. Он не хранится в облаке, а выводится
  /// из мастер-ключа аккаунта: так его знают все устройства владельца, а по
  /// ключу папки (он есть у читателей) мастер-ключ не восстановить.
  ///
  /// Строка info — часть формата данных пользователей, не менять.
  static Future<Uint8List> deriveShareKey(
    Uint8List masterKey,
    String folderHandle,
  ) async {
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 16).deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: utf8.encode(folderHandle),
      info: utf8.encode('transmitter-mega-share-key'),
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}
