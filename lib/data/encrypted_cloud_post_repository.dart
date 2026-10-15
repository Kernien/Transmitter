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
/// <vaultId>/posts/<время>_<id>.post               — зашифрованный JSON поста
/// <vaultId>/posts/<время>_<id>~<правка>.note      — комментарий к посту
/// <vaultId>/files/<id>.bin                        — зашифрованный файл
/// ```
/// Каждый пост лежит в отдельном файле, поэтому несколько устройств могут
/// писать одновременно без конфликтов. Имена начинаются со времени, так что
/// сортировка по имени совпадает с хронологией.
///
/// Комментарий лежит рядом с постом, а не внутри: пост не меняется, а правку
/// комментария видно по списку файлов (новое время правки — новое имя), без
/// лишних запросов. Действует самый свежий комментарий. Старые версии
/// приложения читают только `.post` и комментарии не замечают.
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
  static const String _noteExtension = '.note';
  static const String _noteSeparator = '~';

  @override
  final int maxFileSize;

  @override
  Object? get backgroundError => null;

  @override
  bool get isReadOnly => false;

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

  /// Уже расшифрованные комментарии по имени файла в облаке.
  final Map<String, PostNote> _notes = {};

  /// Файлы, которые не удалось расшифровать: повторно их не скачиваем.
  final Set<String> _unreadable = {};

  bool _postsDirReady = false;

  /// Загружалась ли лента хотя бы раз (см. [cachedPosts]).
  bool _fetched = false;
  bool _filesDirReady = false;

  @override
  Future<List<Post>> fetchPosts() async {
    final remote = (await _storage.listFiles(_postsDir))
        .map((f) => f.name)
        .toSet();
    final postNames = remote.where((n) => n.endsWith(_postExtension)).toSet();
    final noteNames = remote.where((n) => n.endsWith(_noteExtension)).toSet();

    // Посты и комментарии, удалённые на других устройствах.
    _cache.removeWhere((name, _) => !postNames.contains(name));
    _notes.removeWhere((name, _) => !noteNames.contains(name));

    bool isFresh(String name, Map<String, Object> cache) =>
        !cache.containsKey(name) && !_unreadable.contains(name);
    await Future.wait([
      for (final name in postNames.where((n) => isFresh(n, _cache)))
        _load(name, (json) => _cache[name] = Post.fromJson(json)),
      for (final name in noteNames.where((n) => isFresh(n, _notes)))
        _load(name, (json) => _notes[name] = PostNote.fromJson(json)),
    ]);

    _fetched = true;
    return _assemble();
  }

  @override
  List<Post>? get cachedPosts => _fetched ? _assemble() : null;

  /// Известные посты с комментариями, от старых к новым.
  List<Post> _assemble() {
    final notes = _latestNotes();
    return [for (final p in _cache.values) p.withNote(notes[p.id])]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Самый свежий комментарий для каждого поста.
  Map<String, PostNote> _latestNotes() {
    final latest = <String, PostNote>{};
    for (final note in _notes.values) {
      final current = latest[note.postId];
      if (current == null || note.editedAt.isAfter(current.editedAt)) {
        latest[note.postId] = note;
      }
    }
    return latest;
  }

  Future<void> _load(
    String fileName,
    void Function(Map<String, dynamic> json) store,
  ) async {
    try {
      final encrypted = await _storage.download('$_postsDir/$fileName');
      final json = utf8.decode(await _cipher.decrypt(encrypted));
      store(jsonDecode(json) as Map<String, dynamic>);
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
    debugPrint('Skipped unreadable file $fileName: $error');
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
    await _deleteNotes(_noteFilesFor(post));
    final attachment = post.attachment;
    if (attachment != null) {
      await _storage.delete(_attachmentPath(attachment));
    }
  }

  @override
  Future<Post> setNote(Post post, String text) async {
    final trimmed = text.trim();
    // Старые комментарии удаляем после записи нового: при сбое посередине
    // останется лишний файл, но текст не пропадёт.
    final old = _noteFilesFor(post);
    PostNote? note;
    if (trimmed.isNotEmpty) {
      note = PostNote(
        postId: post.id,
        text: trimmed,
        editedAt: _clock().toUtc(),
        editorDevice: _deviceName,
      );
      final fileName = _noteFileNameFor(post, note);
      await _storage.upload(
        '$_postsDir/$fileName',
        await _cipher.encrypt(utf8.encode(jsonEncode(note.toJson()))),
      );
      _notes[fileName] = note;
    }
    await _deleteNotes(old.where((name) => !_isCurrent(name, note)));
    return post.withNote(note);
  }

  bool _isCurrent(String name, PostNote? note) =>
      note != null && _notes[name] == note;

  /// Файлы комментариев поста, известные по последнему списку из облака.
  List<String> _noteFilesFor(Post post) => [
    for (final entry in _notes.entries)
      if (entry.value.postId == post.id) entry.key,
  ];

  Future<void> _deleteNotes(Iterable<String> names) async {
    for (final name in names.toList()) {
      await _storage.delete('$_postsDir/$name');
      _notes.remove(name);
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

  /// Путь к зашифрованному файлу вложения в облаке (для публичной доски).
  static String attachmentPath(String vaultId, String attachmentId) =>
      '$vaultId/files/$attachmentId.bin';

  static String _fileNameFor(Post post) =>
      '${_baseNameFor(post)}$_postExtension';

  static String _noteFileNameFor(Post post, PostNote note) =>
      '${_baseNameFor(post)}$_noteSeparator'
      '${_timestamp(note.editedAt)}$_noteExtension';

  static String _baseNameFor(Post post) =>
      '${_timestamp(post.createdAt)}_${post.id}';

  static String _timestamp(DateTime time) =>
      time.millisecondsSinceEpoch.toString().padLeft(15, '0');
}
