import 'dart:convert';
import 'dart:typed_data';

import '../core/crypto/board_signature.dart';
import '../core/crypto/cipher.dart';
import '../core/errors/app_error.dart';
import '../domain/board_snapshot.dart';

/// Опись не прошла проверку подписи: её записал не владелец или она
/// повреждена.
class BoardSignatureException implements Exception, CodedError {
  const BoardSignatureException();

  @override
  ErrorCode get code => ErrorCode.boardSignatureInvalid;

  @override
  Map<String, Object> get args => const {};

  @override
  String toString() => describeForLog(this);
}

/// Формат файла описи доски в облаке:
/// ```
/// [1 байт версии][64 байта подписи Ed25519][зашифрованный JSON]
/// ```
/// Подписаны версия и шифротекст: читатель сначала проверяет подпись и
/// только потом расшифровывает.
class BoardManifestCodec {
  const BoardManifestCodec(this._cipher);

  static const int _version = 1;

  final Cipher _cipher;

  Future<Uint8List> encode(BoardSnapshot snapshot, BoardSigner signer) async {
    final encrypted = await _cipher.encrypt(
      utf8.encode(jsonEncode(snapshot.toJson())),
    );
    final signed = Uint8List.fromList([_version, ...encrypted]);
    final signature = await signer.sign(signed);
    return Uint8List.fromList([_version, ...signature, ...encrypted]);
  }

  /// Бросает [BoardSignatureException], если подпись неверна, и
  /// `DecryptionException`, если опись не расшифровывается.
  Future<BoardSnapshot> decode(Uint8List bytes, BoardVerifier verifier) async {
    const header = 1 + BoardSigner.signatureLength;
    if (bytes.length <= header || bytes.first != _version) {
      throw const BoardSignatureException();
    }
    final signature = bytes.sublist(1, header);
    final encrypted = bytes.sublist(header);
    final signed = Uint8List.fromList([_version, ...encrypted]);
    if (!await verifier.verify(signed, signature)) {
      throw const BoardSignatureException();
    }
    final json = utf8.decode(await _cipher.decrypt(encrypted));
    return BoardSnapshot.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}
