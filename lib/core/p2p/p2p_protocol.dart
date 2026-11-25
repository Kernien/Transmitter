import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Вспомогательные методы криптографического протокола P2P.
class P2pProtocol {
  P2pProtocol._();

  static const int defaultDiscoveryPort = 47822;

  /// Вычисляет необратимый анонимный хэш доски для маяка обнаружения в локальной сети.
  /// Никто без ключа доски не сможет восстановить ключ или идентификатор.
  static String discoveryHash(List<int> secret) {
    final hmac = Hmac(sha256, secret);
    final digest = hmac.convert(utf8.encode('trm-p2p-discovery-v1'));
    return digest.toString().substring(0, 16);
  }

  /// Вычисляет HMAC подтверждения знания ключа при рукопожатии пиров.
  static String computeAuthProof(List<int> secret, String nonce) {
    final hmac = Hmac(sha256, secret);
    return hmac.convert(utf8.encode(nonce)).toString();
  }

  /// Проверяет подлинность доказательства.
  static bool verifyAuthProof(
    List<int> secret,
    String nonce,
    String proof,
  ) {
    final expected = computeAuthProof(secret, nonce);
    return expected == proof;
  }
}

/// Информация об обнаруженном пире в сети.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.peerId,
    required this.address,
    required this.tcpPort,
    required this.matchingHashes,
  });

  final String peerId;
  final String address;
  final int tcpPort;
  final List<String> matchingHashes;

  @override
  String toString() =>
      'DiscoveredPeer($peerId at $address:$tcpPort, boards: $matchingHashes)';
}
