import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Пара PKCE (RFC 7636) для OAuth без секрета клиента.
///
/// Вычисляется синхронно: в вебе окно входа должно открыться в том же
/// обработчике нажатия, иначе браузер его заблокирует.
class Pkce {
  Pkce._(this.verifier, this.challenge);

  factory Pkce.generate([Random? random]) =>
      Pkce.fromVerifier(randomUrlSafeString(64, random));

  factory Pkce.fromVerifier(String verifier) => Pkce._(
        verifier,
        base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', ''),
      );

  static const String method = 'S256';

  final String verifier;
  final String challenge;
}

const String _unreserved =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// Случайная строка из символов, допустимых в URL без кодирования.
String randomUrlSafeString(int length, [Random? random]) {
  final rnd = random ?? Random.secure();
  return String.fromCharCodes(
    List.generate(length, (_) => _unreserved.codeUnitAt(rnd.nextInt(_unreserved.length))),
  );
}
