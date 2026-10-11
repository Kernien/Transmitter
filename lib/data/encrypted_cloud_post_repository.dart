import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto/cipher.dart';
import '../core/storage/cloud_storage.dart';
import '../core/utils/clock.dart';
import '../core/utils/link_detector.dart';
import '../core/vault/vault_key.dart';
import '../domain/post.dart';
import 'post_repository.dart';

typedef IdGenerator = String Function();

/// Посты в облаке, зашифрованные на устройстве.
///
/// Раскладка в облаке:
/// ```
/// <vaultId>/posts/<время>_<id>.post   — зашифрованный JSON поста
/// <vaultId>/files/<id>.bin            — зашифрованное содержимое файла
/// ```
/// Каждый пост лежит в отдельном файле, поэтому несколько устройств могут
/// писать одновременно без конфликтов. Имена начинаются со времени, так что
/// сортировка по имени совпадает с хронологией.
class EncryptedCloudPostRepository implements PostRepository {
  EncryptedCloudPostRepository({
    required this._storage,
    required String vaultId,
    required this._cipher,
    required this._deviceName,
    this.maxFileSize = VaultKey.defaultMaxFileSize,
    Clock? clock,
    IdGenerator? idGenerator,
    this._linkDetector = const LinkDetector(),
  }) : _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? const Uuid().v4,
       _postsDir = '$vaultId/posts',
       _filesDir = '$vaultId/files';

  static const String _postExtension = '.post';

  @override
  final int maxFileSize;

  final CloudStorage _storage;
  final Cipher _cipher;
  final String _deviceName;
  final Clock _clock;
  final IdGenerator _newId;
  final LinkDetector _linkDetector;
  final String _postsDir;
  final String _filesDir;

  /// Уже расшифрованные посты по имени файла в облаке.
  final Map<String, Post> _cache = {};

  /// Файлы, которые не удалось расшифровать: повторно их не скачиваем.
  final Set<String> _unreadable = {};

  bool _postsDirReady = false;
  bool _filesDirReady = false;

  @override
  Future<List<Post>> fetchPosts() async {
    final remote = (await _storage.listFiles(_postsDir))
        .map((f) => f.name)
        .where((name) => name.endsWith(_postExtension))
        .toSet();

    // Посты, удалённые на других устройствах.
    _cache.removeWhere((name, _) => !remote.contains(name));

    final fresh = remote.where(
      (n) => !_cache.containsKey(n) && !_unreadable.contains(n),
    );
    await Future.wait(fresh.map(_loadPost));

    final posts = _cache.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return posts;
  }

  Future<void> _loadPost(String fileName) async {
    try {
      final encrypted = await _storage.download('$_postsDir/$fileName');
      final json = utf8.decode(await _cipher.decrypt(encrypted));
      _cache[fileName] = Post.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } on StorageNotFoundException {
      // Файл удалили, пока мы его скачивали.
    } on DecryptionException catch (e) {
      _markUnreadable(fileName, e);
    } on FormatException catch (e) {
      _markUnreadable(fileName, e);
    } on TypeError catch (e) {
      _markUnreadable(fileName, e);
    }
  }

  void _markUnreadable(String fileName, Object error) {
    debugPrint('Skipped unreadable post $fileName: $error');
    _unreadable.add(fileName);
  }

  @override
  Future<Post> sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError('Empty text');
    return _publish(
      _newPost(
        kind: _linkDetector.isLink(trimmed) ? PostKind.link : PostKind.text,
        text: trimmed,
      ),
    );
  }

  @override
  Future<Post> sendFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String caption = '',
  }) async {
    if (bytes.length > maxFileSize) {
      throw FileTooLargeException(bytes.length, maxFileSize);
    }
    final attachment = Attachment(
      id: _newId(),
      fileName: fileName,
      size: bytes.length,
      mimeType: mimeType,
    );
    if (!_filesDirReady) {
      await _storage.ensureFolder(_filesDir);
      _filesDirReady = true;
    }
    await _storage.upload(
      _attachmentPath(attachment),
      await _cipher.encrypt(bytes),
    );
    return _publish(
      _newPost(
        kind: PostKind.file,
        text: caption.trim(),
        attachment: attachment,
      ),
    );
  }

  @override
  Future<Uint8List> downloadAttachment(Attachment attachment) async =>
      _cipher.decrypt(await _storage.download(_attachmentPath(attachment)));

  @override
  Future<void> deletePost(Post post) async {
    final fileName = _fileNameFor(post);
    await _storage.delete('$_postsDir/$fileName');
    _cache.remove(fileName);
    final attachment = post.attachment;
    if (attachment != null) {
      await _storage.delete(_attachmentPath(attachment));
    }
  }

  Post _newPost({
    required PostKind kind,
    required String text,
    Attachment? attachment,
  }) => Post(
    id: _newId(),
    kind: kind,
    createdAt: _clock().toUtc(),
    senderDevice: _deviceName,
    text: text,
    attachment: attachment,
  );

  Future<Post> _publish(Post post) async {
    if (!_postsDirReady) {
      await _storage.ensureFolder(_postsDir);
      _postsDirReady = true;
    }
    final fileName = _fileNameFor(post);
    final encrypted = await _cipher.encrypt(
      utf8.encode(jsonEncode(post.toJson())),
    );
    await _storage.upload('$_postsDir/$fileName', encrypted);
    _cache[fileName] = post;
    return post;
  }

  String _attachmentPath(Attachment a) => '$_filesDir/${a.id}.bin';

  static String _fileNameFor(Post post) {
    final ts = post.createdAt.millisecondsSinceEpoch.toString().padLeft(
      15,
      '0',
    );
    return '${ts}_${post.id}$_postExtension';
  }
}
