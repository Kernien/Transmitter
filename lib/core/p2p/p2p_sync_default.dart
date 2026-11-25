import 'dart:async';

import '../storage/cloud_storage.dart';
import '../vault/vault_key.dart';
import 'p2p_protocol.dart';

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

/// Заглушка TCP-синхронизации для сред без серверных сокетов (веб).
class IoP2pSyncService {
  IoP2pSyncService({required CloudStorage storage, String? peerId});

  final String peerId = 'web_peer';
  int get tcpPort => 0;

  Stream<String> get onBoardSynced => const Stream.empty();

  Future<int> start() async => 0;
  Future<String> registerBoard(VaultKey key) async => '';
  void unregisterBoard(String discoveryHash) {}
  P2pBoardEntry? boardEntryByHash(String hash) => null;
  Future<void> syncWithPeer(DiscoveredPeer peer) async {}
  Future<void> stop() async {}
  void dispose() {}
}
