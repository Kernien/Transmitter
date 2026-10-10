import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Токены OAuth одного облака на этом устройстве.
@immutable
class OAuthCredentials {
  const OAuthCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory OAuthCredentials.decode(String encoded) {
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return OAuthCredentials(
      accessToken: json['access'] as String,
      refreshToken: json['refresh'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (json['exp'] as num).toInt(),
        isUtc: true,
      ),
    );
  }

  /// Запас времени: токен обновляется заранее, чтобы не истечь посреди запроса.
  static const Duration refreshMargin = Duration(minutes: 2);

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool needsRefreshAt(DateTime now) => !now.isBefore(expiresAt.subtract(refreshMargin));

  String encode() => jsonEncode({
        'access': accessToken,
        'refresh': refreshToken,
        'exp': expiresAt.toUtc().millisecondsSinceEpoch,
      });
}
