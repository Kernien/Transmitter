import 'dart:math';

import 'package:flutter/foundation.dart';

import '../storage/cloud_provider_id.dart';

/// Ключ доступа к одной базе постов.
///
/// Кто знает [secret], тот может читать и писать в базу, поэтому ключ
/// хранится только в защищённом хранилище устройства.
@immutable
class VaultKey {
  VaultKey({
    required List<int> secret,
    required this.provider,
    required this.label,
  }) : secret = Uint8List.fromList(secret) {
    if (secret.length != secretLength) {
      throw ArgumentError('Секрет должен быть $secretLength байта');
    }
  }

  factory VaultKey.generate({
    required CloudProviderId provider,
    required String label,
    Random? random,
  }) {
    final rnd = random ?? Random.secure();
    return VaultKey(
      secret: List<int>.generate(secretLength, (_) => rnd.nextInt(256)),
      provider: provider,
      label: label,
    );
  }

  static const int secretLength = 32;

  final Uint8List secret;
  final CloudProviderId provider;

  /// Название, которое видит пользователь (например, «Работа»).
  final String label;

  VaultKey copyWith({String? label}) =>
      VaultKey(secret: secret, provider: provider, label: label ?? this.label);

  /// Один и тот же ключ, даже если локальные названия различаются.
  bool sameVaultAs(VaultKey other) =>
      provider == other.provider && listEquals(secret, other.secret);

  @override
  bool operator ==(Object other) =>
      other is VaultKey && sameVaultAs(other) && label == other.label;

  @override
  int get hashCode => Object.hash(provider, label, Object.hashAll(secret));
}
