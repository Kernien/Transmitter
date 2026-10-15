import 'dart:convert';

import '../core/crypto/aes_gcm_cipher.dart';
import '../core/crypto/board_signature.dart';
import '../core/crypto/vault_key_derivation.dart';
import '../core/storage/cloud_connection_service.dart';
import '../core/storage/cloud_storage.dart';
import '../core/storage/cloud_provider_id.dart';
import '../core/storage/public_sharing.dart';
import '../core/vault/reader_key.dart';
import '../core/vault/vault_key.dart';
import '../data/board_publisher.dart';
import '../data/encrypted_cloud_post_repository.dart';
import '../data/post_repository.dart';
import '../data/public_board_repository.dart';
import '../data/publishing_post_repository.dart';

/// Собирает [PostRepository] для выбранного ключа: выводит секреты,
/// берёт хранилище подключённого облака и настраивает шифрование.
///
/// Открытые сессии живут, пока работает приложение: при повторном входе в
/// ленту уже скачанные записи не загружаются заново. Сессия базы
/// пересоздаётся после нового входа в облако (у старой устаревший токен) и
/// после смены имени устройства (им подписываются новые записи).
class VaultSessionFactory {
  VaultSessionFactory({
    required this._connections,
    required this._deviceName,
    this._readers = const {},
    this._derivation = const VaultKeyDerivation(),
  });

  /// Чтение публичных досок без входа — по облакам.
  final Map<CloudProviderId, PublicFileReader> _readers;

  final CloudConnectionService _connections;

  /// Имя устройства берётся в момент открытия базы: его можно поменять.
  final String Function() _deviceName;
  final VaultKeyDerivation _derivation;

  final Map<String, ({String stamp, Future<PostRepository> session})>
  _sessions = {};
  final Map<String, PostRepository> _boards = {};

  /// Лента базы. Если облако умеет открывать файлы по ссылке, изменения
  /// сразу попадают и в публичную доску (когда доступ на чтение открыт).
  Future<PostRepository> open(VaultKey key) {
    final id = '${key.provider.code}:${base64Url.encode(key.secret)}';
    final stamp =
        '${_connections.connectionEpoch(key.provider)}/${_deviceName()}/'
        '${key.maxFileSize}';
    final cached = _sessions[id];
    if (cached != null && cached.stamp == stamp) return cached.session;

    final session = _create(key);
    _sessions[id] = (stamp: stamp, session: session);
    // Неудачную попытку (нет сети, не подключено облако) не запоминаем.
    session.then(
      (_) {},
      onError: (Object _) {
        if (identical(_sessions[id]?.session, session)) _sessions.remove(id);
      },
    );
    return session;
  }

  Future<PostRepository> _create(VaultKey key) async {
    final secrets = await _derivation.derive(key.secret);
    final storage = _connections.storageFor(key.provider);
    final repository = _repository(key, storage, secrets);
    final publisher = await _publisher(key, storage, secrets, repository);
    return publisher == null
        ? repository
        : PublishingPostRepository(repository, publisher);
  }

  /// Публичная доска у читателя — только чтение, вход в облако не нужен.
  PostRepository openAsReader(ReaderKey key) {
    final reader = _readers[key.provider];
    if (reader == null) {
      throw UnsupportedError('${key.provider.title} boards are not supported');
    }
    return _boards.putIfAbsent(
      '${key.provider.code}:${key.locator}',
      () => PublicBoardRepository(reader: reader, key: key),
    );
  }

  /// Управление доступом на чтение; `null`, если облако не умеет
  /// открывать файлы по ссылке.
  Future<BoardPublisher?> openBoard(VaultKey key) async {
    final secrets = await _derivation.derive(key.secret);
    final storage = _connections.storageFor(key.provider);
    return _publisher(
      key,
      storage,
      secrets,
      _repository(key, storage, secrets),
    );
  }

  EncryptedCloudPostRepository _repository(
    VaultKey key,
    CloudStorage storage,
    VaultSecrets secrets,
  ) => EncryptedCloudPostRepository(
    storage: storage,
    vaultId: secrets.vaultId,
    cipher: AesGcmCipher(secrets.encryptionKey),
    deviceName: _deviceName(),
    maxFileSize: key.maxFileSize,
  );

  Future<BoardPublisher?> _publisher(
    VaultKey key,
    CloudStorage storage,
    VaultSecrets secrets,
    PostRepository posts,
  ) async {
    if (storage is! PublicSharing) return null;
    return BoardPublisher(
      storage: storage,
      sharing: storage as PublicSharing,
      vaultId: secrets.vaultId,
      cipher: AesGcmCipher(secrets.encryptionKey),
      encryptionKey: secrets.encryptionKey,
      signer: await BoardSigner.fromSeed(
        await _derivation.boardSigningSeed(key.secret),
      ),
      provider: key.provider,
      loadPosts: posts.fetchPosts,
    );
  }
}
