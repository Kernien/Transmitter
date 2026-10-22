import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto/board_signature.dart';
import '../core/crypto/cipher.dart';
import '../core/storage/cloud_provider_id.dart';
import '../core/storage/cloud_storage.dart';
import '../core/storage/public_sharing.dart';
import '../core/utils/clock.dart';
import '../core/vault/reader_key.dart';
import '../domain/board_snapshot.dart';
import '../domain/post.dart';
import 'board_manifest_codec.dart';
import 'encrypted_cloud_post_repository.dart';

/// Состояние публичной доски — в облаке владельца, зашифровано ключом базы,
/// поэтому его видят все устройства владельца.
@immutable
class BoardState {
  const BoardState({
    required this.label,
    required this.manifestName,
    required this.manifestLocator,
    required this.fileLocators,
    required this.contentHash,
  });

  factory BoardState.fromJson(Map<String, dynamic> json) => BoardState(
    label: json['label'] as String,
    manifestName: json['manifest'] as String,
    manifestLocator: json['locator'] as String,
    fileLocators: (json['files'] as Map<String, dynamic>).map(
      (id, locator) => MapEntry(id, locator as String),
    ),
    contentHash: json['hash'] as String,
  );

  /// Название доски для читателей — фиксируется при открытии доступа, чтобы
  /// устройства владельца с разными локальными названиями не спорили.
  final String label;

  /// Имя файла описи (случайное: после повторного открытия доступа старые
  /// ключи читателей не находят новую опись).
  final String manifestName;
  final String manifestLocator;

  /// Открытые по ссылке файлы: id вложения → локатор.
  final Map<String, String> fileLocators;

  /// Хеш содержимого последней записанной описи — чтобы не переписывать её
  /// без изменений.
  final String contentHash;

  BoardState copyWith({
    String? label,
    Map<String, String>? fileLocators,
    String? contentHash,
  }) => BoardState(
    label: label ?? this.label,
    manifestName: manifestName,
    manifestLocator: manifestLocator,
    fileLocators: fileLocators ?? this.fileLocators,
    contentHash: contentHash ?? this.contentHash,
  );

  Map<String, dynamic> toJson() => {
    'v': 1,
    'label': label,
    'manifest': manifestName,
    'locator': manifestLocator,
    'files': fileLocators,
    'hash': contentHash,
  };
}

/// Публичная доска со стороны владельца: открыть и закрыть доступ на
/// чтение, держать опись в актуальном виде.
///
/// Раскладка в облаке:
/// ```
/// <vaultId>/board/state.bin        — [BoardState], ключом базы
/// <vaultId>/board/<случайное>.board — опись для читателей (открыта по ссылке)
/// ```
/// Файлы вложений не копируются: они уже зашифрованы ключом базы и
/// открываются по ссылке как есть. Читатель получает ключ шифрования, но не
/// секрет базы и не доступ к облаку — изменить ничего не может.
class BoardPublisher {
  BoardPublisher({
    required this._storage,
    required this._sharing,
    required String vaultId,
    required this._cipher,
    required List<int> encryptionKey,
    required this._signer,
    required this._provider,
    required this._loadPosts,
    Clock? clock,
    String Function()? idGenerator,
    this._stateTtl = const Duration(minutes: 1),
  }) : _vaultId = vaultId,
       _encryptionKey = Uint8List.fromList(encryptionKey),
       _dir = '$vaultId/board',
       _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? const Uuid().v4,
       _manifests = BoardManifestCodec(_cipher);

  final CloudStorage _storage;
  final PublicSharing _sharing;
  final String _vaultId;
  final Cipher _cipher;
  final Uint8List _encryptionKey;
  final BoardSigner _signer;
  final CloudProviderId _provider;

  /// Текущие записи базы — чтобы сразу заполнить опись при открытии доступа.
  final Future<List<Post>> Function() _loadPosts;
  final Clock _clock;
  final String Function() _newId;
  final Duration _stateTtl;
  final String _dir;
  final BoardManifestCodec _manifests;

  BoardState? _state;
  DateTime? _stateLoadedAt;

  static const String _manifestExtension = '.board';

  String get _statePath => '$_dir/state.bin';
  String _manifestPath(BoardState s) => '$_dir/${s.manifestName}';

  /// Текущее состояние доски; `null` — доступ на чтение не открыт. Другие
  /// устройства владельца могут открыть или закрыть доступ, поэтому
  /// состояние перечитывается из облака не реже раза в минуту.
  Future<BoardState?> state({bool refresh = false}) async {
    final loadedAt = _stateLoadedAt;
    if (!refresh &&
        loadedAt != null &&
        _clock().difference(loadedAt) < _stateTtl) {
      return _state;
    }
    try {
      final bytes = await _storage.download(_statePath);
      _state = BoardState.fromJson(
        jsonDecode(utf8.decode(await _cipher.decrypt(bytes)))
            as Map<String, dynamic>,
      );
    } on StorageNotFoundException {
      _state = null;
    }
    _stateLoadedAt = _clock();
    return _state;
  }

  ReaderKey readerKeyFor(BoardState state) => ReaderKey(
    provider: _provider,
    label: state.label,
    locator: state.manifestLocator,
    encryptionKey: _encryptionKey,
    ownerPublicKey: _signer.publicKey,
  );

  /// Открывает доступ на чтение (или возвращает ключ, если доступ уже
  /// открыт). Опись сразу заполняется текущими записями базы.
  Future<ReaderKey> open({required String label}) async {
    final existing = await state(refresh: true);
    if (existing != null) return readerKeyFor(existing);

    await _storage.ensureFolder(_dir);
    // Доступ закрыт — любая опись в папке осталась от прерванной попытки.
    for (final file in await _storage.listFiles(_dir)) {
      if (file.name.endsWith(_manifestExtension)) {
        await _storage.delete('$_dir/${file.name}');
      }
    }
    final manifestName = '${_newId()}$_manifestExtension';
    final empty = BoardSnapshot(
      label: label,
      updatedAt: _clock().toUtc(),
      posts: const [],
      fileLocators: const {},
    );
    // Опись должна существовать до того, как её откроют по ссылке.
    final manifestPath = '$_dir/$manifestName';
    await _storage.upload(
      manifestPath,
      await _manifests.encode(empty, _signer),
    );
    final String manifestLocator;
    try {
      manifestLocator = await _sharing.publish(manifestPath);
    } catch (_) {
      // Например, нет права на ссылки: опись без ссылки не нужна.
      await _storage.delete(manifestPath);
      rethrow;
    }
    final opened = BoardState(
      label: label,
      manifestName: manifestName,
      manifestLocator: manifestLocator,
      fileLocators: const {},
      contentHash: _hashOf(empty),
    );
    await _saveState(opened);
    await sync(await _loadPosts());
    return readerKeyFor(opened);
  }

  /// Новое название доски для читателей (база переименована). Возвращает
  /// `false`, если доступ на чтение не открыт.
  Future<bool> rename(String label) async {
    final current = await state(refresh: true);
    if (current == null) return false;
    if (current.label != label) {
      await _saveState(current.copyWith(label: label));
      await sync(await _loadPosts());
    }
    return true;
  }

  /// Закрывает доступ: опись удаляется (её ссылка перестаёт работать),
  /// ссылки на файлы закрываются. Все выданные ключи читателей больше не
  /// работают; сами записи и файлы остаются у владельца.
  Future<void> close() async {
    final current = await state(refresh: true);
    if (current == null) return;
    // Сначала состояние — чтобы другие устройства перестали обновлять опись.
    await _storage.delete(_statePath);
    _state = null;
    // Ссылка закрывается явно: в MEGA это ссылка на папку, и удаление описи
    // её не закрыло бы.
    await _sharing.unpublish(
      _manifestPath(current),
      current.manifestLocator,
    );
    await _storage.delete(_manifestPath(current));
    for (final entry in current.fileLocators.entries) {
      await _sharing.unpublish(_attachmentPath(entry.key), entry.value);
    }
  }

  /// Приводит опись в соответствие с записями базы. Если доступ не открыт
  /// или ничего не изменилось, в облако ничего не пишется.
  Future<void> sync(List<Post> posts) async {
    var current = await state();
    if (current == null) return;

    final files = await _publishFiles(current, posts);
    var snapshot = _snapshot(current, posts, files);
    if (_hashOf(snapshot) == current.contentHash) return;

    // Перед записью убеждаемся, что доступ не закрыли с другого устройства.
    current = await state(refresh: true);
    if (current == null) return;
    snapshot = _snapshot(current, posts, files);
    final contentHash = _hashOf(snapshot);
    if (contentHash == current.contentHash) return;

    await _storage.upload(
      _manifestPath(current),
      await _manifests.encode(snapshot, _signer),
    );
    await _saveState(
      current.copyWith(fileLocators: files, contentHash: contentHash),
    );
  }

  /// Ссылки на файлы всех записей: известные берутся из состояния, новые
  /// открываются. Файлы удалённых записей просто выпадают из описи — сами
  /// файлы удалены вместе с записями.
  Future<Map<String, String>> _publishFiles(
    BoardState state,
    List<Post> posts,
  ) async {
    final files = <String, String>{};
    for (final post in posts) {
      final attachment = post.attachment;
      if (attachment == null) continue;
      final known = state.fileLocators[attachment.id];
      if (known != null) {
        files[attachment.id] = known;
        continue;
      }
      try {
        files[attachment.id] = await _sharing.publish(
          _attachmentPath(attachment.id),
        );
      } on StorageNotFoundException {
        // Файл удалили, пока мы обновляли опись.
      }
    }
    return files;
  }

  BoardSnapshot _snapshot(
    BoardState state,
    List<Post> posts,
    Map<String, String> files,
  ) {
    // Однозначный порядок, чтобы все устройства владельца получали одинаковую
    // опись и не переписывали её друг за другом.
    final ordered = [...posts]
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final sortedFiles = Map.fromEntries(
      files.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return BoardSnapshot(
      label: state.label,
      updatedAt: _clock().toUtc(),
      posts: ordered,
      fileLocators: sortedFiles,
    );
  }

  /// Хеш содержимого описи без времени обновления.
  static String _hashOf(BoardSnapshot snapshot) {
    final json = snapshot.toJson()..remove('ts');
    return hash.sha256.convert(utf8.encode(jsonEncode(json))).toString();
  }

  Future<void> _saveState(BoardState state) async {
    await _storage.upload(
      _statePath,
      await _cipher.encrypt(utf8.encode(jsonEncode(state.toJson()))),
    );
    _state = state;
    _stateLoadedAt = _clock();
  }

  String _attachmentPath(String attachmentId) =>
      EncryptedCloudPostRepository.attachmentPath(_vaultId, attachmentId);
}
