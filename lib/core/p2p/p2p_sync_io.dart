import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../crypto/vault_key_derivation.dart';
import '../storage/cloud_storage.dart';
import '../vault/vault_key.dart';
import 'p2p_protocol.dart';
import 'p2p_socket_codec.dart';

/// Регистрационная запись доски для P2P-синхронизации.
class P2pBoardEntry {
  const P2pBoardEntry({
    required this.key,
    required this.vaultFolder,
    required this.discoveryHash,
  });

  final VaultKey key;
  final String vaultFolder;
  final String discoveryHash;
}

/// Сервис прямой симметричной синхронизации постов и файлов между пирами по TCP.
class IoP2pSyncService {
  IoP2pSyncService({
    required this.storage,
    String? peerId,
    this.derivation = const VaultKeyDerivation(),
  }) : peerId = peerId ?? const Uuid().v4();

  final String peerId;
  final CloudStorage storage;
  final VaultKeyDerivation derivation;

  ServerSocket? _serverSocket;
  int get tcpPort => _serverSocket?.port ?? 0;

  final Map<String, P2pBoardEntry> _registeredBoards = {};
  final Map<String, DateTime> _lastSyncTimes = {};

  final StreamController<String> _boardSyncedController =
      StreamController<String>.broadcast();

  Stream<String> get onBoardSynced => _boardSyncedController.stream;

  Future<int> start() async {
    await stop();
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _serverSocket!.listen(_handleIncomingClient);
    return _serverSocket!.port;
  }

  Future<String> registerBoard(VaultKey key) async {
    final secrets = await derivation.derive(key.secret);
    final hash = P2pProtocol.discoveryHash(key.secret);
    final vaultFolder = secrets.vaultId;

    _registeredBoards[hash] = P2pBoardEntry(
      key: key,
      vaultFolder: vaultFolder,
      discoveryHash: hash,
    );
    return hash;
  }

  void unregisterBoard(String discoveryHash) {
    _registeredBoards.remove(discoveryHash);
  }

  P2pBoardEntry? boardEntryByHash(String hash) => _registeredBoards[hash];

  Future<void> syncWithPeer(DiscoveredPeer peer, {bool force = false}) async {
    // Инициатором выступает узел с лексикографически меньшим peerId
    if (!force && peerId.compareTo(peer.peerId) >= 0) {
      return;
    }

    final now = DateTime.now();
    final lastSync = _lastSyncTimes[peer.peerId];
    if (lastSync != null && now.difference(lastSync).inSeconds < 3) {
      return;
    }
    _lastSyncTimes[peer.peerId] = now;

    Socket? socket;
    try {
      socket = await Socket.connect(
        peer.address,
        peer.tcpPort,
        timeout: const Duration(seconds: 5),
      );

      for (final hash in peer.matchingHashes) {
        final entry = _registeredBoards[hash];
        if (entry == null) continue;

        await _runClientSession(socket, entry);
      }
    } catch (e) {
      debugPrint('P2P sync error with ${peer.peerId}: $e');
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  Future<void> _runClientSession(Socket socket, P2pBoardEntry entry) async {
    final session = _P2pConnectionSession(
      socket: socket,
      storage: storage,
      entry: entry,
      onUpdated: (_) => _boardSyncedController.add(entry.vaultFolder),
    );

    await session.runAsClient(peerId);
  }

  void _handleIncomingClient(Socket socket) {
    final session = _P2pConnectionSession(
      socket: socket,
      storage: storage,
      entryResolver: (hash) => _registeredBoards[hash],
      onUpdated: (vaultFolder) => _boardSyncedController.add(vaultFolder),
    );

    session.runAsServer();
  }

  Future<void> stop() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }

  void dispose() {
    stop();
    _boardSyncedController.close();
  }
}

/// Асинхронный контроллер сессии P2P-соединения с полной поддержкой параллельных запросов.
class _P2pConnectionSession {
  _P2pConnectionSession({
    required this.socket,
    required this.storage,
    this.entry,
    this.entryResolver,
    this.onUpdated,
  });

  final Socket socket;
  final CloudStorage storage;
  P2pBoardEntry? entry;
  final P2pBoardEntry? Function(String hash)? entryResolver;
  final dynamic Function(String vaultFolder)? onUpdated;

  final Map<String, Completer<Uint8List>> _pendingFiles = {};
  Completer<Map<String, dynamic>>? _handshakeAckCompleter;
  Completer<Map<String, dynamic>>? _manifestCompleter;
  Map<String, dynamic>? _remoteManifest;
  Completer<void>? _syncDoneCompleter;
  bool _receivedSyncDone = false;

  String? _serverNonce;
  bool _hasUpdates = false;

  void _listenSocket() {
    final incoming = P2pSocketCodec.decodeMessages(
      socket.map((c) => Uint8List.fromList(c)),
    );

    incoming.listen(
      _handleMessage,
      onError: (_) => socket.destroy(),
      onDone: () => socket.destroy(),
      cancelOnError: true,
    );
  }

  Future<void> runAsClient(String myPeerId) async {
    _listenSocket();
    final clientNonce = _randomNonce();

    _handshakeAckCompleter = Completer<Map<String, dynamic>>();
    P2pSocketCodec.sendMessage(socket, {
      't': 'hello',
      'peer': myPeerId,
      'board': entry!.discoveryHash,
      'nonce': clientNonce,
    });

    final ack = await _handshakeAckCompleter!.future.timeout(const Duration(seconds: 5));
    final serverNonce = ack['nonce'] as String?;
    final serverProof = ack['auth'] as String?;
    if (serverNonce == null || serverProof == null) return;

    if (!P2pProtocol.verifyAuthProof(entry!.key.secret, clientNonce, serverProof)) {
      debugPrint('P2P Client: auth verification failed');
      return;
    }

    final clientProof = P2pProtocol.computeAuthProof(entry!.key.secret, serverNonce);
    P2pSocketCodec.sendMessage(socket, {
      't': 'auth',
      'auth': clientProof,
    });

    await _syncBoardData();
  }

  void runAsServer() {
    _listenSocket();
  }

  Future<void> _handleMessage(Map<String, dynamic> msg) async {
    final type = msg['t'] as String?;

    if (type == 'hello') {
      final boardHash = msg['board'] as String?;
      final clientNonce = msg['nonce'] as String?;
      if (boardHash == null || clientNonce == null) {
        socket.destroy();
        return;
      }

      entry = entryResolver?.call(boardHash);
      if (entry == null) {
        socket.destroy();
        return;
      }

      _serverNonce = _randomNonce();
      final proof = P2pProtocol.computeAuthProof(entry!.key.secret, clientNonce);
      P2pSocketCodec.sendMessage(socket, {
        't': 'hello_ack',
        'nonce': _serverNonce,
        'auth': proof,
      });
      return;
    }

    if (type == 'hello_ack') {
      _handshakeAckCompleter?.complete(msg);
      return;
    }

    if (type == 'auth') {
      final clientProof = msg['auth'] as String?;
      final nonce = _serverNonce;
      if (entry == null || nonce == null || clientProof == null) {
        socket.destroy();
        return;
      }

      if (!P2pProtocol.verifyAuthProof(entry!.key.secret, nonce, clientProof)) {
        debugPrint('P2P Server: client auth verification failed');
        socket.destroy();
        return;
      }

      // Запускаем синхронизацию без блокировки входящего потока сокета
      unawaited(_syncBoardData());
      return;
    }

    if (type == 'manifest') {
      _remoteManifest = msg;
      if (_manifestCompleter != null && !_manifestCompleter!.isCompleted) {
        _manifestCompleter!.complete(msg);
      }
      return;
    }

    if (type == 'get_file') {
      final path = msg['path'] as String?;
      if (path != null) {
        try {
          final bytes = await storage.download(path);
          P2pSocketCodec.sendMessage(socket, {
            't': 'file_data',
            'path': path,
            'bytes': base64Encode(bytes),
          });
        } catch (e) {
          debugPrint('P2P get_file failed for $path: $e');
        }
      }
      return;
    }

    if (type == 'file_data') {
      final path = msg['path'] as String?;
      final bytesBase64 = msg['bytes'] as String?;
      if (path != null && bytesBase64 != null) {
        final bytes = base64Decode(bytesBase64);
        final completer = _pendingFiles.remove(path);
        completer?.complete(bytes);
      }
      return;
    }

    if (type == 'sync_done') {
      _receivedSyncDone = true;
      if (_syncDoneCompleter != null && !_syncDoneCompleter!.isCompleted) {
        _syncDoneCompleter!.complete();
      }
      return;
    }
  }

  Future<void> _syncBoardData() async {
    final currentEntry = entry;
    if (currentEntry == null) return;

    final postsDir = '${currentEntry.vaultFolder}/posts';
    final filesDir = '${currentEntry.vaultFolder}/files';
    await storage.ensureFolder(postsDir);
    await storage.ensureFolder(filesDir);

    final localPosts = await storage.listFiles(postsDir);
    final localFiles = await storage.listFiles(filesDir);

    // Отправляем манифест наших файлов
    P2pSocketCodec.sendMessage(socket, {
      't': 'manifest',
      'board': currentEntry.discoveryHash,
      'posts': [
        for (final p in localPosts) {'name': p.name, 'size': p.size},
      ],
      'files': [
        for (final f in localFiles) {'name': f.name, 'size': f.size},
      ],
    });

    final remoteManifest = _remoteManifest ??
        await (_manifestCompleter ??= Completer<Map<String, dynamic>>())
            .future
            .timeout(const Duration(seconds: 10));

    final remotePosts = (remoteManifest['posts'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final remoteFiles = (remoteManifest['files'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    final localPostNames = localPosts.map((p) => p.name).toSet();
    final localFileNames = localFiles.map((f) => f.name).toSet();

    // Скачиваем отсутствующие посты
    for (final rp in remotePosts) {
      final name = rp['name'] as String;
      if (!localPostNames.contains(name)) {
        final path = '$postsDir/$name';
        final completer = Completer<Uint8List>();
        _pendingFiles[path] = completer;
        P2pSocketCodec.sendMessage(socket, {'t': 'get_file', 'path': path});

        final bytes = await completer.future.timeout(const Duration(seconds: 15));
        await storage.upload(path, bytes);
        _hasUpdates = true;
      }
    }

    // Скачиваем отсутствующие вложения
    for (final rf in remoteFiles) {
      final name = rf['name'] as String;
      if (!localFileNames.contains(name)) {
        final path = '$filesDir/$name';
        final completer = Completer<Uint8List>();
        _pendingFiles[path] = completer;
        P2pSocketCodec.sendMessage(socket, {'t': 'get_file', 'path': path});

        final bytes = await completer.future.timeout(const Duration(seconds: 30));
        await storage.upload(path, bytes);
        _hasUpdates = true;
      }
    }

    if (_hasUpdates) {
      onUpdated?.call(currentEntry.vaultFolder);
    }

    P2pSocketCodec.sendMessage(socket, {'t': 'sync_done'});
    if (!_receivedSyncDone) {
      try {
        await (_syncDoneCompleter ??= Completer<void>())
            .future
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
  }

  static String _randomNonce() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }
}
