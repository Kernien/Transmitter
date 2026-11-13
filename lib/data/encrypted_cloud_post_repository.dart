import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto/cipher.dart';
import '../core/persistence/blob_cache.dart';
import '../core/storage/cloud_storage.dart';
import '../core/utils/clock.dart';
import '../core/utils/link_detector.dart';
import '../core/vault/vault_key.dart';
import '../domain/post.dart';
import 'post_repository.dart';

typedef IdGenerator = String Function();

/// Посты в облаке (с шифрованием или в открытом виде — через [Cipher]).
///
/// Раскладка в облаке:
/// ```
/// <vaultId>/posts/<время>_<id>.post               — JSON поста
/// <vaultId>/posts/<время>_<id>~<правка>.note      — комментарий к посту
/// <vaultId>/files/<id>.bin                        — зашифрованный файл
/// <vaultId>/files/<имя файла>                     — файл в базе без шифрования
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
    this.plainFileNames = false,
    Clock? clock,
    IdGenerator? idGenerator,
    this._linkDetector = const LinkDetector(),
    this._blobs = const NoBlobCache(),
  }) : _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? const Uuid().v4,
       _postsDir = '$vaultId/posts',
       _filesDir = '$vaultId/files';

  static const String _postExtension = '.post';
  static const String _noteExtension = '.note';
  static const String _noteSeparator = '~';
  static const String _indexKey = 'index.json';

  /// Порог для автоматического сохранения вложений в локальный кеш при
  /// отправке/скачивании целиком в памяти (крупные файлы передаются потоком).
  static const int maxCachedAttachmentSize = 32 * 1024 * 1024;

  @override
  final int maxFileSize;

  /// Класть ли файлы вложений под их настоящими именами (для баз без
  /// шифрования, чтобы файлы открывались прямо в облаке).
  final bool plainFileNames;

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

  /// Зашифрованные файлы постов и комментариев на устройстве — чтобы не
  /// качать их заново после перезапуска. Имена файлов уникальны и не
  /// меняются (правка комментария — новый файл), поэтому кеш не устаревает.
  final BlobCache _blobs;

  /// Имена файлов из последнего сохранённого списка кеша.
  Set<String>? _indexed;
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
    for (final entry in _cache.entries) {
      final attachment = entry.value.attachment;
      if (!postNames.contains(entry.key) && attachment != null) {
        await _blobs.delete(attachmentCacheKey(attachment.id));
      }
      final folder = entry.value.folder;
      if (!postNames.contains(entry.key) && folder != null) {
        for (final file in folder.files) {
          await _blobs.delete(attachmentCacheKey(file.id));
        }
      }
    }
    _cache.removeWhere((name, _) => !postNames.contains(name));
    _notes.removeWhere((name, _) => !noteNames.contains(name));

    bool isFresh(String name, Map<String, Object> cache) =>
        !cache.containsKey(name) && !_unreadable.contains(name);
    await Future.wait([
      for (final name in postNames.where((n) => isFresh(n, _cache)))
        _loadPost(name),
      for (final name in noteNames.where((n) => isFresh(n, _notes)))
        _loadNote(name),
    ]);

    _fetched = true;
    await _saveIndex();
    return _assemble();
  }

  @override
  Future<void> warmUp() async {
    if (_fetched) return;
    final names = await _readIndex();
    if (names == null) return;
    await Future.wait([
      for (final name in names)
        if (name.endsWith(_postExtension))
          _loadPost(name, localOnly: true)
        else if (name.endsWith(_noteExtension))
          _loadNote(name, localOnly: true),
    ]);
    _indexed = names;
    _fetched = true;
  }

  Future<void> _loadPost(String name, {bool localOnly = false}) => _load(
    name,
    (json) => _cache[name] = Post.fromJson(json),
    localOnly: localOnly,
  );

  Future<void> _loadNote(String name, {bool localOnly = false}) => _load(
    name,
    (json) => _notes[name] = PostNote.fromJson(json),
    localOnly: localOnly,
  );

  Future<Set<String>?> _readIndex() async {
    final raw = await _blobs.read(_indexKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(utf8.decode(raw)) as List).cast<String>().toSet();
    } on Object {
      return null;
    }
  }

  /// Запоминает, какие файлы известны, и убирает из кеша удалённые.
  Future<void> _saveIndex() async {
    final names = {..._cache.keys, ..._notes.keys};
    final previous = _indexed ??= await _readIndex() ?? {};
    if (setEquals(previous, names)) return;
    for (final gone in previous.difference(names)) {
      await _blobs.delete(gone);
    }
    await _blobs.write(_indexKey, utf8.encode(jsonEncode(names.toList())));
    _indexed = names;
  }

  @override
  List<Post>? get cachedPosts => _fetched ? _assemble() : null;

  /// Известные посты с комментариями, от старых к новым.
  /// Если из-за прерванной правки в облаке осталось два файла `.post` одного
  /// и того же поста (`post.id`), побеждает файл с более поздним именем.
  List<Post> _assemble() {
    final notes = _latestNotes();
    final byId = <String, Post>{};
    final sortedNames = _cache.keys.toList()..sort();
    for (final name in sortedNames) {
      final p = _cache[name]!;
      byId[p.id] = p.withNote(notes[p.id]);
    }
    return byId.values.toList()
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

  /// Файл берётся из кеша на устройстве, а если его там нет (или он
  /// испорчен) — из облака, после чего кладётся в кеш.
  Future<void> _load(
    String fileName,
    void Function(Map<String, dynamic> json) store, {
    bool localOnly = false,
  }) async {
    final cached = await _blobs.read(fileName);
    if (cached != null) {
      if (await _decode(cached, store) == null) return;
      await _blobs.delete(fileName);
    }
    if (localOnly) return;
    try {
      final encrypted = await _storage.download('$_postsDir/$fileName');
      final error = await _decode(encrypted, store);
      if (error == null) {
        await _blobs.write(fileName, encrypted);
      } else {
        _markUnreadable(fileName, error);
      }
    } on StorageNotFoundException {
      // Файл удалили, пока мы его скачивали.
    }
  }

  /// Расшифровывает и разбирает файл; возвращает ошибку или `null`.
  Future<Object?> _decode(
    List<int> encrypted,
    void Function(Map<String, dynamic> json) store,
  ) async {
    try {
      final json = utf8.decode(await _cipher.decrypt(encrypted));
      store(jsonDecode(json) as Map<String, dynamic>);
      return null;
    } on DecryptionException catch (e) {
      return e;
    } on FormatException catch (e) {
      return e;
    } on TypeError catch (e) {
      return e;
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
    ProgressCallback? onProgress,
  }) async {
    if (bytes.length > maxFileSize) {
      throw FileTooLargeException(bytes.length, maxFileSize);
    }
    if (!_filesDirReady) {
      await _storage.ensureFolder(_filesDir);
      _filesDirReady = true;
    }
    final attachmentId = plainFileNames
        ? await _choosePlainFileName(fileName)
        : _newId();
    final attachment = Attachment(
      id: attachmentId,
      fileName: fileName,
      size: bytes.length,
      mimeType: mimeType,
    );
    final encrypted = await _cipher.encrypt(bytes);
    await _storage.upload(
      _attachmentPath(attachment),
      encrypted,
      onProgress: onProgress,
    );
    if (encrypted.length <= maxCachedAttachmentSize) {
      await _blobs.write(attachmentCacheKey(attachment.id), encrypted);
    }
    return _publish(
      _newPost(
        kind: PostKind.file,
        text: caption.trim(),
        attachment: attachment,
      ),
    );
  }

  @override
  Future<Post> sendFileStream({
    required String fileName,
    required Stream<List<int>> stream,
    required int size,
    String? mimeType,
    String caption = '',
    ProgressCallback? onProgress,
  }) async {
    if (size > maxFileSize) {
      throw FileTooLargeException(size, maxFileSize);
    }
    if (!_filesDirReady) {
      await _storage.ensureFolder(_filesDir);
      _filesDirReady = true;
    }
    final attachmentId = plainFileNames
        ? await _choosePlainFileName(fileName)
        : _newId();
    final attachment = Attachment(
      id: attachmentId,
      fileName: fileName,
      size: size,
      mimeType: mimeType,
    );
    final encryptedLength = _cipher.encryptedLength(size);
    final encryptedStream = _cipher.encryptStream(stream);
    await _storage.uploadStream(
      _attachmentPath(attachment),
      encryptedStream,
      length: encryptedLength,
      onProgress: onProgress,
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
  Future<Post> sendFolder({
    required String folderName,
    required List<PickedFile> files,
    String caption = '',
    ProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) {
      throw const TransferCancelledException();
    }
    for (final file in files) {
      if (file.isTooLarge || file.size > maxFileSize) {
        throw FileTooLargeException(file.size, maxFileSize);
      }
    }
    if (!_filesDirReady) {
      await _storage.ensureFolder(_filesDir);
      _filesDirReady = true;
    }

    Set<String>? existingPlainNames;
    if (plainFileNames) {
      existingPlainNames = (await _storage.listFiles(_filesDir))
          .map((f) => f.name.toLowerCase())
          .toSet();
    }

    const fileUnitWeight = 1024;
    const maxConcurrency = 6;
    final totalUnits = files.fold(0, (sum, f) => sum + f.size + fileUnitWeight);

    // Сразу распределяем идентификаторы файлов, чтобы параллельные потоки
    // не пересекались по именам в существующем списке plainFileNames.
    final attachments = <Attachment>[
      for (final file in files)
        Attachment(
          id: plainFileNames
              ? _choosePlainFileNameFromExisting(file.name, existingPlainNames!)
              : _newId(),
          fileName: file.name,
          size: file.size,
          mimeType: file.mimeType,
        ),
    ];

    final fileProgress = List<int>.filled(files.length, 0);
    void reportProgress() {
      if (onProgress == null) return;
      var currentTotal = 0;
      for (var i = 0; i < fileProgress.length; i++) {
        currentTotal += fileProgress[i];
      }
      onProgress(currentTotal, totalUnits);
    }

    var nextIndex = 0;
    Object? firstError;
    StackTrace? firstStack;

    Future<void> uploadOne(int index) async {
      final file = files[index];
      final attachment = attachments[index];
      final fileUnits = file.size + fileUnitWeight;

      try {
        if (file.hasBytesInMemory) {
          final encrypted = await _cipher.encrypt(file.bytes);
          await _uploadWithRetry(
            () => _storage.upload(
              _attachmentPath(attachment),
              encrypted,
              onProgress: onProgress == null
                  ? null
                  : (count, total) {
                      if (isCancelled?.call() == true) {
                        throw const TransferCancelledException();
                      }
                      fileProgress[index] =
                          total > 0 ? (count / total * file.size).toInt() : 0;
                      reportProgress();
                    },
            ),
            isCancelled: isCancelled,
          );
          if (encrypted.length <= maxCachedAttachmentSize) {
            await _blobs.write(attachmentCacheKey(attachment.id), encrypted);
          }
        } else {
          final encryptedLength = _cipher.encryptedLength(file.size);
          await _uploadWithRetry(
            () {
              final encryptedStream = _cipher.encryptStream(file.openRead());
              return _storage.uploadStream(
                _attachmentPath(attachment),
                encryptedStream,
                length: encryptedLength,
                onProgress: onProgress == null
                    ? null
                    : (count, total) {
                        if (isCancelled?.call() == true) {
                          throw const TransferCancelledException();
                        }
                        fileProgress[index] =
                            total > 0 ? (count / total * file.size).toInt() : 0;
                        reportProgress();
                      },
              );
            },
            isCancelled: isCancelled,
          );
        }
      } on Object catch (e) {
        if (e is TransferCancelledException || isCancelled?.call() == true) {
          throw const TransferCancelledException();
        }
        final errorStr = e.toString();
        final isDiskLock = errorStr.contains('FileSystemException') ||
            errorStr.contains('PathAccessException') ||
            errorStr.contains('OS Error: The process cannot access');
        if (isDiskLock) {
          final emptyEncrypted = await _cipher.encrypt(Uint8List(0));
          await _storage.upload(_attachmentPath(attachment), emptyEncrypted);
        } else {
          rethrow;
        }
      }

      fileProgress[index] = fileUnits;
      reportProgress();
    }

    Future<void> worker() async {
      while (true) {
        if (firstError != null) return;
        if (isCancelled?.call() == true) {
          firstError ??= const TransferCancelledException();
          return;
        }
        final index = nextIndex++;
        if (index >= files.length) return;
        try {
          await uploadOne(index);
        } on Object catch (e, st) {
          if (firstError == null) {
            firstError = e;
            firstStack = st;
          }
          return;
        }
      }
    }

    final workerCount =
        files.length < maxConcurrency ? files.length : maxConcurrency;
    if (workerCount > 0) {
      await Future.wait([for (var w = 0; w < workerCount; w++) worker()]);
    }

    if (firstError != null) {
      if (firstError is TransferCancelledException ||
          isCancelled?.call() == true) {
        throw const TransferCancelledException();
      }
      Error.throwWithStackTrace(firstError!, firstStack!);
    }

    if (isCancelled?.call() == true) {
      throw const TransferCancelledException();
    }

    final entries = <FolderEntry>[
      for (var i = 0; i < files.length; i++)
        FolderEntry(
          id: attachments[i].id,
          relativePath: files[i].pathInFolder,
          size: files[i].size,
          mimeType: files[i].mimeType,
        ),
    ];

    final folder = FolderAttachment(name: folderName, files: entries);
    return _publish(
      _newPost(
        kind: PostKind.folder,
        text: caption.trim(),
        folder: folder,
      ),
    );
  }

  Future<void> _uploadWithRetry(
    Future<void> Function() action, {
    int maxAttempts = 3,
    bool Function()? isCancelled,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (isCancelled?.call() == true) {
        throw const TransferCancelledException();
      }
      try {
        await action();
        return;
      } catch (e) {
        if (isCancelled?.call() == true) throw const TransferCancelledException();
        if (attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (1 << attempt)),
        );
      }
    }
  }

  @override
  Future<Uint8List> downloadAttachment(
    Attachment attachment, {
    ProgressCallback? onProgress,
  }) async {
    final key = attachmentCacheKey(attachment.id);
    final cached = await _blobs.read(key);
    if (cached != null) {
      try {
        final result = await _cipher.decrypt(cached);
        onProgress?.call(cached.length, cached.length);
        return result;
      } on DecryptionException {
        await _blobs.delete(key);
      }
    }
    final encrypted = await _storage.download(
      _attachmentPath(attachment),
      onProgress: onProgress,
    );
    final bytes = await _cipher.decrypt(encrypted);
    if (encrypted.length <= maxCachedAttachmentSize) {
      await _blobs.write(key, encrypted);
    }
    return bytes;
  }

  @override
  Stream<Uint8List> downloadAttachmentStream(
    Attachment attachment, {
    ProgressCallback? onProgress,
  }) async* {
    final key = attachmentCacheKey(attachment.id);
    final cached = await _blobs.read(key);
    if (cached != null) {
      try {
        final result = await _cipher.decrypt(cached);
        onProgress?.call(cached.length, cached.length);
        yield result;
        return;
      } on DecryptionException {
        await _blobs.delete(key);
      }
    }
    final encryptedStream = _storage.downloadStream(
      _attachmentPath(attachment),
      onProgress: onProgress,
    );
    yield* _cipher.decryptStream(encryptedStream);
  }

  @override
  Future<void> deletePost(Post post) async {
    final fileNames = [
      for (final entry in _cache.entries)
        if (entry.value.id == post.id) entry.key,
    ];
    final fallbackName = _fileNameFor(post);
    if (!fileNames.contains(fallbackName)) {
      fileNames.add(fallbackName);
    }
    for (final fileName in fileNames) {
      await _storage.delete('$_postsDir/$fileName');
      _cache.remove(fileName);
      await _blobs.delete(fileName);
    }
    if (post.attachment case final attachment?) {
      await _blobs.delete(attachmentCacheKey(attachment.id));
      await _storage.delete(_attachmentPath(attachment));
    }
    if (post.folder case final folder?) {
      for (final file in folder.files) {
        await _blobs.delete(attachmentCacheKey(file.id));
        await _storage.delete(_attachmentPath(file.toAttachment()));
      }
    }
    await _deleteNotes(_noteFilesFor(post));
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
      final encrypted = await _cipher.encrypt(
        utf8.encode(jsonEncode(note.toJson())),
      );
      await _storage.upload('$_postsDir/$fileName', encrypted);
      await _blobs.write(fileName, encrypted);
      _notes[fileName] = note;
    }
    await _deleteNotes(old.where((name) => !_isCurrent(name, note)));
    return post.withNote(note);
  }

  @override
  Future<Post> updateFileContent({
    required Post post,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
    ProgressCallback? onProgress,
  }) async {
    if (bytes.length > maxFileSize) {
      throw FileTooLargeException(bytes.length, maxFileSize);
    }
    final oldAttachment = post.attachment;
    if (oldAttachment == null) {
      throw ArgumentError('Post has no attachment');
    }
    if (!_filesDirReady) {
      await _storage.ensureFolder(_filesDir);
      _filesDirReady = true;
    }
    final targetName = fileName ?? oldAttachment.fileName;
    final newAttachmentId = plainFileNames
        ? await _choosePlainFileName(targetName)
        : _newId();
    final newAttachment = Attachment(
      id: newAttachmentId,
      fileName: targetName,
      size: bytes.length,
      mimeType: mimeType ?? oldAttachment.mimeType,
    );
    final encrypted = await _cipher.encrypt(bytes);
    await _storage.upload(
      _attachmentPath(newAttachment),
      encrypted,
      onProgress: onProgress,
    );
    if (encrypted.length <= maxCachedAttachmentSize) {
      await _blobs.write(attachmentCacheKey(newAttachment.id), encrypted);
    }
    final updatedPost = await _replacePostRecord(
      post,
      post.withAttachment(newAttachment),
    );
    if (oldAttachment.id != newAttachment.id) {
      await _blobs.delete(attachmentCacheKey(oldAttachment.id));
      await _storage.delete(_attachmentPath(oldAttachment));
    }
    return updatedPost;
  }

  @override
  Future<Post?> updateFolderStructure({
    required Post post,
    required FolderAttachment updatedFolder,
    List<String> removedEntryIds = const [],
  }) async {
    if (updatedFolder.files.isEmpty) {
      final postWithRemoved = post.folder == null
          ? post
          : post.withFolder(
              FolderAttachment(
                name: updatedFolder.name,
                files: [
                  for (final id in removedEntryIds)
                    FolderEntry(id: id, relativePath: id, size: 0),
                ],
              ),
            );
      await deletePost(postWithRemoved);
      return null;
    }
    final updatedPost = await _replacePostRecord(
      post,
      post.withFolder(updatedFolder),
    );
    final remainingIds = updatedFolder.files.map((f) => f.id).toSet();
    for (final removedId in removedEntryIds.toSet()) {
      if (remainingIds.contains(removedId)) continue;
      await _blobs.delete(attachmentCacheKey(removedId));
      await _storage.delete(
        attachmentPath(
          _filesDir,
          removedId,
          plainFileNames: plainFileNames,
          inFilesDir: true,
        ),
      );
    }
    return updatedPost;
  }

  @override
  Future<Post> replaceFolderEntry({
    required Post post,
    required String entryId,
    required Uint8List bytes,
    String? newRelativePath,
    String? mimeType,
    ProgressCallback? onProgress,
  }) async {
    if (bytes.length > maxFileSize) {
      throw FileTooLargeException(bytes.length, maxFileSize);
    }
    final folder = post.folder;
    if (folder == null) {
      throw ArgumentError('Post has no folder');
    }
    final oldIndex = folder.files.indexWhere((e) => e.id == entryId);
    if (oldIndex < 0) {
      throw ArgumentError('Folder entry not found: $entryId');
    }
    final oldEntry = folder.files[oldIndex];
    final targetPath = (newRelativePath ?? oldEntry.relativePath)
        .replaceAll('\\', '/');
    final targetFileName = targetPath.split('/').last;

    if (!_filesDirReady) {
      await _storage.ensureFolder(_filesDir);
      _filesDirReady = true;
    }
    final newId = plainFileNames
        ? await _choosePlainFileName(targetFileName)
        : _newId();
    final newEntry = FolderEntry(
      id: newId,
      relativePath: targetPath,
      size: bytes.length,
      mimeType: mimeType ?? oldEntry.mimeType,
    );
    final newAttachment = newEntry.toAttachment();
    final encrypted = await _cipher.encrypt(bytes);
    await _storage.upload(
      _attachmentPath(newAttachment),
      encrypted,
      onProgress: onProgress,
    );
    if (encrypted.length <= maxCachedAttachmentSize) {
      await _blobs.write(attachmentCacheKey(newEntry.id), encrypted);
    }

    final updatedFiles = [...folder.files];
    updatedFiles[oldIndex] = newEntry;
    final updatedFolder = FolderAttachment(
      name: folder.name,
      files: updatedFiles,
    );
    final updatedPost = await _replacePostRecord(
      post,
      post.withFolder(updatedFolder),
    );
    if (oldEntry.id != newEntry.id) {
      await _blobs.delete(attachmentCacheKey(oldEntry.id));
      await _storage.delete(_attachmentPath(oldEntry.toAttachment()));
    }
    return updatedPost;
  }

  @override
  Future<Post> addFilesToFolder({
    required Post post,
    required List<PickedFile> files,
    String targetSubdir = '',
    ProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) {
      throw const TransferCancelledException();
    }
    final folder = post.folder;
    if (folder == null) {
      throw ArgumentError('Post has no folder');
    }
    if (files.isEmpty) return post;
    for (final file in files) {
      if (file.isTooLarge || file.size > maxFileSize) {
        throw FileTooLargeException(file.size, maxFileSize);
      }
    }
    if (!_filesDirReady) {
      await _storage.ensureFolder(_filesDir);
      _filesDirReady = true;
    }

    Set<String>? existingPlainNames;
    if (plainFileNames) {
      existingPlainNames = (await _storage.listFiles(_filesDir))
          .map((f) => f.name.toLowerCase())
          .toSet();
    }

    final cleanSubdir = targetSubdir
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .join('/');

    final existingPaths = folder.files
        .map((e) => e.relativePath.toLowerCase())
        .toSet();

    String chooseUniqueRelativePath(String rawPath) {
      final full = cleanSubdir.isEmpty ? rawPath : '$cleanSubdir/$rawPath';
      final slash = full.lastIndexOf('/');
      final dirPart = slash < 0 ? '' : full.substring(0, slash + 1);
      final namePart = slash < 0 ? full : full.substring(slash + 1);
      final dot = namePart.lastIndexOf('.');
      final (base, ext) = dot > 0
          ? (namePart.substring(0, dot), namePart.substring(dot))
          : (namePart, '');
      var candidate = '$dirPart$namePart';
      for (var i = 2; existingPaths.contains(candidate.toLowerCase()); i++) {
        candidate = '$dirPart$base ($i)$ext';
      }
      existingPaths.add(candidate.toLowerCase());
      return candidate;
    }

    final attachments = <Attachment>[];
    final relativePaths = <String>[];
    for (final file in files) {
      final relPath = chooseUniqueRelativePath(file.pathInFolder);
      relativePaths.add(relPath);
      attachments.add(
        Attachment(
          id: plainFileNames
              ? _choosePlainFileNameFromExisting(file.name, existingPlainNames!)
              : _newId(),
          fileName: file.name,
          size: file.size,
          mimeType: file.mimeType,
        ),
      );
    }

    const fileUnitWeight = 1024;
    const maxConcurrency = 6;
    final totalUnits = files.fold(0, (sum, f) => sum + f.size + fileUnitWeight);
    final fileProgress = List<int>.filled(files.length, 0);

    void reportProgress() {
      if (onProgress == null) return;
      var currentTotal = 0;
      for (var i = 0; i < fileProgress.length; i++) {
        currentTotal += fileProgress[i];
      }
      onProgress(currentTotal, totalUnits);
    }

    var nextIndex = 0;
    Object? firstError;
    StackTrace? firstStack;

    Future<void> uploadOne(int index) async {
      final file = files[index];
      final attachment = attachments[index];
      final fileUnits = file.size + fileUnitWeight;
      if (file.hasBytesInMemory) {
        final encrypted = await _cipher.encrypt(file.bytes);
        await _uploadWithRetry(
          () => _storage.upload(
            _attachmentPath(attachment),
            encrypted,
            onProgress: onProgress == null
                ? null
                : (count, total) {
                    if (isCancelled?.call() == true) {
                      throw const TransferCancelledException();
                    }
                    fileProgress[index] =
                        total > 0 ? (count / total * file.size).toInt() : 0;
                    reportProgress();
                  },
          ),
          isCancelled: isCancelled,
        );
        if (encrypted.length <= maxCachedAttachmentSize) {
          await _blobs.write(attachmentCacheKey(attachment.id), encrypted);
        }
      } else {
        final encryptedLength = _cipher.encryptedLength(file.size);
        await _uploadWithRetry(
          () {
            final encryptedStream = _cipher.encryptStream(file.openRead());
            return _storage.uploadStream(
              _attachmentPath(attachment),
              encryptedStream,
              length: encryptedLength,
              onProgress: onProgress == null
                  ? null
                  : (count, total) {
                      if (isCancelled?.call() == true) {
                        throw const TransferCancelledException();
                      }
                      fileProgress[index] =
                          total > 0 ? (count / total * file.size).toInt() : 0;
                      reportProgress();
                    },
            );
          },
          isCancelled: isCancelled,
        );
      }
      fileProgress[index] = fileUnits;
      reportProgress();
    }

    Future<void> worker() async {
      while (true) {
        if (firstError != null) return;
        if (isCancelled?.call() == true) {
          firstError ??= const TransferCancelledException();
          return;
        }
        final index = nextIndex++;
        if (index >= files.length) return;
        try {
          await uploadOne(index);
        } on Object catch (e, st) {
          if (firstError == null) {
            firstError = e;
            firstStack = st;
          }
          return;
        }
      }
    }

    final workerCount =
        files.length < maxConcurrency ? files.length : maxConcurrency;
    if (workerCount > 0) {
      await Future.wait([for (var w = 0; w < workerCount; w++) worker()]);
    }

    if (firstError != null) {
      if (firstError is TransferCancelledException ||
          isCancelled?.call() == true) {
        throw const TransferCancelledException();
      }
      Error.throwWithStackTrace(firstError!, firstStack!);
    }

    final newEntries = <FolderEntry>[
      ...folder.files,
      for (var i = 0; i < files.length; i++)
        FolderEntry(
          id: attachments[i].id,
          relativePath: relativePaths[i],
          size: files[i].size,
          mimeType: files[i].mimeType,
        ),
    ];

    return _replacePostRecord(
      post,
      post.withFolder(FolderAttachment(name: folder.name, files: newEntries)),
    );
  }

  /// Записывает новую ревизию поста под новым именем файла в `_postsDir`,
  /// чтобы другие устройства гарантированно увидели изменение при `fetchPosts`
  /// (не читая устаревший локальный кеш старого файла `.post`), после чего
  /// удаляет прежний файл `.post`.
  Future<Post> _replacePostRecord(Post oldPost, Post updatedPost) async {
    if (!_postsDirReady) {
      await _storage.ensureFolder(_postsDir);
      _postsDirReady = true;
    }
    final oldNames = [
      for (final entry in _cache.entries)
        if (entry.value.id == oldPost.id) entry.key,
    ];
    final fallbackOldName = _fileNameFor(oldPost);
    if (!oldNames.contains(fallbackOldName)) {
      oldNames.add(fallbackOldName);
    }

    final revToken = _newId().replaceAll('-', '').substring(0, 8);
    final newFileName =
        '${_timestamp(updatedPost.createdAt)}_${updatedPost.id}_$revToken$_postExtension';
    final encrypted = await _cipher.encrypt(
      utf8.encode(jsonEncode(updatedPost.toJson())),
    );
    await _storage.upload('$_postsDir/$newFileName', encrypted);
    await _blobs.write(newFileName, encrypted);
    _cache[newFileName] = updatedPost;

    for (final oldName in oldNames) {
      if (oldName == newFileName) continue;
      await _storage.delete('$_postsDir/$oldName');
      _cache.remove(oldName);
      await _blobs.delete(oldName);
    }
    await _saveIndex();
    return updatedPost.withNote(_latestNotes()[updatedPost.id]);
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
      await _blobs.delete(name);
    }
  }

  Post _newPost({
    required PostKind kind,
    required String text,
    Attachment? attachment,
    FolderAttachment? folder,
  }) => Post(
    id: _newId(),
    kind: kind,
    createdAt: _clock().toUtc(),
    senderDevice: _deviceName,
    text: text,
    attachment: attachment,
    folder: folder,
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
    await _blobs.write(fileName, encrypted);
    _cache[fileName] = post;
    return post;
  }

  String _attachmentPath(Attachment a) =>
      attachmentPath(_filesDir, a.id, plainFileNames: plainFileNames, inFilesDir: true);

  /// Путь к файлу вложения в облаке (для публичной доски).
  static String attachmentPath(
    String baseDir,
    String attachmentId, {
    bool plainFileNames = false,
    bool inFilesDir = false,
  }) {
    final dir = inFilesDir ? baseDir : '$baseDir/files';
    return plainFileNames ? '$dir/$attachmentId' : '$dir/$attachmentId.bin';
  }

  /// Выбирает свободное имя файла в `files/` для базы без шифрования:
  /// убирает запрещённые в облаках символы, а при совпадении имён добавляет
  /// « (2)», « (3)»… перед расширением.
  Future<String> _choosePlainFileName(String original) async {
    final existing = (await _storage.listFiles(_filesDir))
        .map((f) => f.name.toLowerCase())
        .toSet();
    return _choosePlainFileNameFromExisting(original, existing);
  }

  static String _choosePlainFileNameFromExisting(
    String original,
    Set<String> existing,
  ) {
    final safe = _sanitizeFileName(original);
    final dot = safe.lastIndexOf('.');
    final (base, ext) = dot > 0
        ? (safe.substring(0, dot), safe.substring(dot))
        : (safe, '');
    var candidate = safe;
    for (var i = 2; existing.contains(candidate.toLowerCase()); i++) {
      candidate = '$base ($i)$ext';
    }
    existing.add(candidate.toLowerCase());
    return candidate;
  }

  static String _sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\x00-\x1F\\/:*?"<>|]'), '_')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'file';
    return cleaned;
  }

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
