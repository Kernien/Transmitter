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
    this.maxFileSize = defaultMaxFileSize,
  }) : secret = Uint8List.fromList(secret) {
    if (secret.length != secretLength) {
      throw ArgumentError('Секрет должен быть $secretLength байта');
    }
    if (maxFileSize < _mb || maxFileSize > absoluteMaxFileSize) {
      throw ArgumentError('Недопустимый лимит размера файла: $maxFileSize');
    }
  }

  factory VaultKey.generate({
    required CloudProviderId provider,
    required String label,
    int maxFileSize = defaultMaxFileSize,
    Random? random,
  }) {
    final rnd = random ?? Random.secure();
    return VaultKey(
      secret: List<int>.generate(secretLength, (_) => rnd.nextInt(256)),
      provider: provider,
      label: label,
      maxFileSize: maxFileSize,
    );
  }

  static const int secretLength = 32;

  static const int _mb = 1024 * 1024;

  /// Лимит для ключей, созданных до появления выбора (и по умолчанию).
  static const int defaultMaxFileSize = 25 * _mb;

  /// Варианты лимита при создании ключа. Больше 100 МБ не предлагаем:
  /// файл целиком обрабатывается в памяти и отправляется одним запросом.
  static const List<int> maxFileSizeOptions = [
    10 * _mb,
    25 * _mb,
    50 * _mb,
    100 * _mb,
  ];

  static const int absoluteMaxFileSize = 100 * _mb;

  final Uint8List secret;
  final CloudProviderId provider;

  /// Название, которое видит пользователь (например, «Работа»).
  final String label;

  /// Максимальный размер файла в этой базе. Задаётся создателем ключа и
  /// передаётся вместе с ключом, поэтому одинаков на всех устройствах.
  final int maxFileSize;

  VaultKey copyWith({String? label}) => VaultKey(
    secret: secret,
    provider: provider,
    label: label ?? this.label,
    maxFileSize: maxFileSize,
  );

  /// Один и тот же ключ, даже если локальные названия различаются.
  bool sameVaultAs(VaultKey other) =>
      provider == other.provider && listEquals(secret, other.secret);

  @override
  bool operator ==(Object other) =>
      other is VaultKey &&
      sameVaultAs(other) &&
      label == other.label &&
      maxFileSize == other.maxFileSize;

  @override
  int get hashCode =>
      Object.hash(provider, label, maxFileSize, Object.hashAll(secret));
}
