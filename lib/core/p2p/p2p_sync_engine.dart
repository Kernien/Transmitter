import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/cloud_storage.dart';
import '../vault/vault_key.dart';
import 'p2p_protocol.dart';
import 'platform_p2p_discovery.dart';
import 'platform_p2p_sync.dart';

/// Высокоуровневый координатор P2P-синхронизации досок.
class P2pSyncEngine extends ChangeNotifier {
  P2pSyncEngine({
    required CloudStorage storage,
    String? peerId,
    IoP2pDiscoveryService? discovery,
    IoP2pSyncService? sync,
  }) : discovery = discovery ?? IoP2pDiscoveryService(peerId: peerId),
       sync = sync ?? IoP2pSyncService(storage: storage, peerId: peerId);

  final IoP2pDiscoveryService discovery;
  final IoP2pSyncService sync;

  StreamSubscription? _peerSub;
  StreamSubscription? _syncSub;
  bool _running = false;

  bool get isRunning => _running;
  Iterable<VaultKey> get registeredVaults => _registeredKeys.values;

  final Map<String, VaultKey> _registeredKeys = {};
  final Map<String, DateTime> _peerHeartbeats = {};

  Stream<String> get onBoardSynced => sync.onBoardSynced;

  /// Запускает сетевые сервисы обнаружения и синхронизации.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    final tcpPort = await sync.start();
    await discovery.start(tcpPort: tcpPort);

    _peerSub = discovery.onPeerDiscovered.listen((peer) {
      handlePeerDiscovered(peer);
    });

    _syncSub = sync.onBoardSynced.listen((_) {
      notifyListeners();
    });
  }

  void handlePeerDiscovered(DiscoveredPeer peer) {
    for (final hash in peer.matchingHashes) {
      _peerHeartbeats['${peer.peerId}_$hash'] = DateTime.now();
    }
    sync.syncWithPeer(peer);
    notifyListeners();
  }

  /// Регистрирует ключ P2P-доски для отслеживания и анонса.
  /// При первой зарегистрированной доске автоматически запускает сетевые сокеты.
  Future<void> registerVault(VaultKey key) async {
    final hash = await sync.registerBoard(key);
    _registeredKeys[hash] = key;
    discovery.setAdvertisedBoards(_registeredKeys.keys);
    if (!_running) {
      await start();
    }
  }

  /// Удаляет регистрацию доски.
  /// Если P2P-досок больше нет, освобождает сокеты.
  void unregisterVault(VaultKey key) {
    final hash = P2pProtocol.discoveryHash(key.secret);
    _registeredKeys.remove(hash);
    _peerHeartbeats.removeWhere((k, _) => k.endsWith('_$hash'));
    sync.unregisterBoard(hash);
    discovery.setAdvertisedBoards(_registeredKeys.keys);
    if (_registeredKeys.isEmpty && _running) {
      stop();
    }
  }

  /// Возвращает число активных устройств в сети для указанной доски
  /// (видевших друг друга в последние 15 секунд).
  int activePeersFor(VaultKey key) {
    final hash = P2pProtocol.discoveryHash(key.secret);
    final now = DateTime.now();
    var count = 0;
    _peerHeartbeats.removeWhere((k, lastSeen) => now.difference(lastSeen).inSeconds > 15);

    for (final entry in _peerHeartbeats.entries) {
      if (entry.key.endsWith('_$hash')) {
        count++;
      }
    }
    return count;
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _peerSub?.cancel();
    _peerSub = null;
    await _syncSub?.cancel();
    _syncSub = null;
    await discovery.stop();
    await sync.stop();
  }

  @override
  void dispose() {
    stop();
    discovery.dispose();
    sync.dispose();
    super.dispose();
  }
}
