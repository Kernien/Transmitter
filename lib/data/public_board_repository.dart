import 'package:flutter/foundation.dart';

import '../core/crypto/aes_gcm_cipher.dart';
import '../core/crypto/board_signature.dart';
import '../core/errors/app_error.dart';
import '../core/storage/cloud_storage.dart';
import '../core/storage/public_sharing.dart';
import '../core/vault/reader_key.dart';
import '../core/vault/vault_key.dart';
import '../domain/post.dart';
import 'board_manifest_codec.dart';
import 'post_repository.dart';

/// Владелец закрыл доступ к доске: опись по ссылке больше не открывается.
class BoardClosedException implements Exception, CodedError {
  const BoardClosedException();

  @override
  ErrorCode get code => ErrorCode.boardClosed;

  @override
  Map<String, Object> get args => const {};

  @override
  String toString() => describeForLog(this);
}

/// Публичная доска со стороны читателя: только чтение, без входа в облако.
///
/// Лента — из описи по ссылке (подпись владельца проверяется до
/// расшифровки), файлы — по своим ссылкам, тем же ключом. Изменить ничего
/// нельзя: методы записи бросают [UnsupportedError], а интерфейс их не
/// предлагает ([isReadOnly]).
class PublicBoardRepository implements PostRepository {
  PublicBoardRepository({required this._reader, required ReaderKey key})
    : _locator = key.locator,
      _cipher = AesGcmCipher(key.encryptionKey),
      _verifier = BoardVerifier(key.ownerPublicKey);

  final PublicFileReader _reader;
  final String _locator;
  final AesGcmCipher _cipher;
  final BoardVerifier _verifier;

  /// Адреса файлов из последней прочитанной описи.
  Map<String, String> _files = const {};

  @override
  bool get isReadOnly => true;

  @override
  int get maxFileSize => VaultKey.absoluteMaxFileSize;

  @override
  Object? get backgroundError => null;

  @override
  Future<List<Post>> fetchPosts() async {
    final Uint8List bytes;
    try {
      bytes = await _reader.download(_locator);
    } on StorageNotFoundException {
      throw const BoardClosedException();
    }
    final snapshot = await BoardManifestCodec(_cipher).decode(bytes, _verifier);
    _files = snapshot.fileLocators;
    return snapshot.posts;
  }

  @override
  Future<Uint8List> downloadAttachment(Attachment attachment) async {
    final locator = _files[attachment.id];
    if (locator == null) throw StorageNotFoundException(attachment.fileName);
    return _cipher.decrypt(await _reader.download(locator));
  }

  @override
  Future<Post> sendText(String text) => _readOnly();

  @override
  Future<Post> sendFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String caption = '',
  }) => _readOnly();

  @override
  Future<void> deletePost(Post post) => _readOnly();

  @override
  Future<Post> setNote(Post post, String text) => _readOnly();

  static Never _readOnly() =>
      throw UnsupportedError('Public board is read-only');
}
