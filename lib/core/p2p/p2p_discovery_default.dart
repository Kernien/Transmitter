import 'dart:async';

import 'p2p_protocol.dart';

/// Заглушка discovery для сред без UDP сокетов (веб).
class IoP2pDiscoveryService {
  IoP2pDiscoveryService({String? peerId, int? discoveryPort})
    : peerId = peerId ?? 'web_peer';

  final String peerId;

  Stream<DiscoveredPeer> get onPeerDiscovered => const Stream.empty();

  Future<void> start({required int tcpPort}) async {}
  void setAdvertisedBoards(Iterable<String> discoveryHashes) {}
  void broadcastBeacon() {}
  Future<void> stop() async {}
  void dispose() {}
}
