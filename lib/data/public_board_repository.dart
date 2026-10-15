import 'package:flutter/foundation.dart';

import '../core/crypto/aes_gcm_cipher.dart';
import '../core/crypto/board_signature.dart';
import '../core/errors/app_error.dart';
import '../core/persistence/blob_cache.dart';
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
  PublicBoardRepository({
    required this._reader,
    required ReaderKey key,
    this._blobs = const NoBlobCache(),
  }) : _locator = key.locator,
       _cipher = AesGcmCipher(key.encryptionKey),
       _verifier = BoardVerifier(key.ownerPublicKey);

  final PublicFileReader _reader;
  final String _locator;
  final AesGcmCipher _cipher;
  final BoardVerifier _verifier;

  /// Последняя опись на устройстве — доска открывается сразу, даже без сети.
  final BlobCache _blobs;
  static const String _manifestKey = 'manifest.board';

  /// Адреса файлов из последней прочитанной описи.
  Map<String, String> _files = const {};

  List<Post>? _lastPosts;

  @override
  List<Post>? get cachedPosts => _lastPosts;

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
      // Доступ закрыт — сохранённая копия больше не нужна.
      await _blobs.delete(_manifestKey);
      throw const BoardClosedException();
    }
    final posts = await _apply(bytes);
    await _blobs.write(_manifestKey, bytes);
    return posts;
  }

  @override
  Future<void> warmUp() async {
    if (_lastPosts != null) return;
    final bytes = await _blobs.read(_manifestKey);
    if (bytes == null) return;
    try {
      await _apply(bytes);
    } on Object {
      await _blobs.delete(_manifestKey);
    }
  }

  /// Проверяет подпись, расшифровывает и запоминает опись.
  Future<List<Post>> _apply(Uint8List bytes) async {
    final snapshot = await BoardManifestCodec(_cipher).decode(bytes, _verifier);
    _files = snapshot.fileLocators;
    return _lastPosts = snapshot.posts;
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
