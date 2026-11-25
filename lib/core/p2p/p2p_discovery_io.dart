import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'p2p_protocol.dart';

/// Сервис сетевого обнаружения устройств в локальной сети через UDP Broadcast.
class IoP2pDiscoveryService {
  IoP2pDiscoveryService({
    String? peerId,
    this.discoveryPort = P2pProtocol.defaultDiscoveryPort,
  }) : peerId = peerId ?? const Uuid().v4();

  final String peerId;
  final int discoveryPort;

  RawDatagramSocket? _socket;
  Timer? _beaconTimer;

  /// Активные хэши досок этого устройства для анонса.
  final Set<String> _advertisedHashes = {};

  final StreamController<DiscoveredPeer> _peerController =
      StreamController<DiscoveredPeer>.broadcast();

  Stream<DiscoveredPeer> get onPeerDiscovered => _peerController.stream;

  int _tcpPort = 0;

  /// Запускает прослушивание сети и периодическую рассылку маяков.
  Future<void> start({required int tcpPort}) async {
    _tcpPort = tcpPort;
    await stop();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (_) {
      // Если основной порт нельзя переиспользовать, слушаем на свободном порту
      try {
        _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      } catch (e) {
        debugPrint('Failed to bind UDP discovery socket: $e');
        return;
      }
    }

    _socket?.broadcastEnabled = true;
    _socket?.listen(_onSocketData);

    // Периодический маяк каждые 3 секунды
    _beaconTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => broadcastBeacon(),
    );
    broadcastBeacon();
  }

  /// Обновляет список зарегистрированных досок для поиска.
  void setAdvertisedBoards(Iterable<String> discoveryHashes) {
    _advertisedHashes.clear();
    _advertisedHashes.addAll(discoveryHashes);
    if (_advertisedHashes.isNotEmpty) {
      broadcastBeacon();
    }
  }

  /// Отправляет одиночный широковещательный маяк.
  void broadcastBeacon() {
    final socket = _socket;
    if (socket == null || _advertisedHashes.isEmpty || _tcpPort == 0) return;

    final message = jsonEncode({
      't': 'trm_beacon',
      'v': 1,
      'peer': peerId,
      'tcp': _tcpPort,
      'boards': _advertisedHashes.toList(),
    });

    final bytes = utf8.encode(message);
    try {
      socket.send(
        bytes,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
    } catch (e) {
      debugPrint('UDP broadcast beacon error: $e');
    }
  }

  void _onSocketData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _socket;
    if (socket == null) return;

    final datagram = socket.receive();
    if (datagram == null) return;

    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (json['t'] != 'trm_beacon') return;

      final remotePeer = json['peer'] as String?;
      if (remotePeer == null || remotePeer == peerId) return; // Свой же маяк

      final remoteTcp = (json['tcp'] as num?)?.toInt() ?? 0;
      if (remoteTcp <= 0) return;

      final remoteBoards = (json['boards'] as List?)?.cast<String>() ?? [];
      final matches =
          remoteBoards.where((b) => _advertisedHashes.contains(b)).toList();

      if (matches.isNotEmpty) {
        final peer = DiscoveredPeer(
          peerId: remotePeer,
          address: datagram.address.address,
          tcpPort: remoteTcp,
          matchingHashes: matches,
        );
        _peerController.add(peer);
      }
    } catch (_) {
      // Некорректный пакет из сети игнорируем
    }
  }

  /// Останавливает сервис и освобождает сокеты.
  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _peerController.close();
  }
}
