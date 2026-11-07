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
    this.isEncrypted = true,
  }) : secret = Uint8List.fromList(secret) {
    if (secret.length != secretLength) {
      throw ArgumentError('Secret must be $secretLength bytes');
    }
    if (maxFileSize < _mb || maxFileSize > absoluteMaxFileSize) {
      throw ArgumentError('Invalid file size limit: $maxFileSize');
    }
  }

  factory VaultKey.generate({
    required CloudProviderId provider,
    required String label,
    int maxFileSize = defaultMaxFileSize,
    bool isEncrypted = true,
    Random? random,
  }) {
    final rnd = random ?? Random.secure();
    return VaultKey(
      secret: List<int>.generate(secretLength, (_) => rnd.nextInt(256)),
      provider: provider,
      label: label,
      maxFileSize: maxFileSize,
      isEncrypted: isEncrypted,
    );
  }

  static const int secretLength = 32;

  static const int _mb = 1024 * 1024;
  static const int _gb = 1024 * _mb;

  /// Минимальный допустимый лимит размера файла (для совместимости со
  /// старыми ключами и настройками).
  static const int minFileSize = 10 * _mb;

  /// Лимит для ключей, созданных до появления выбора (и по умолчанию).
  static const int defaultMaxFileSize = 25 * _mb;

  /// Значение «без лимита» (1 ТБ — помещается в 53-битные числа JSON/Web и
  /// превышает любой практический размер файла).
  static const int unlimitedFileSize = 1024 * _gb;

  /// Варианты лимита размера файла для базы.
  static const List<int> maxFileSizeOptions = [
    25 * _mb,
    100 * _mb,
    500 * _mb,
    1 * _gb,
    2 * _gb,
    unlimitedFileSize,
  ];

  static const int absoluteMaxFileSize = unlimitedFileSize;

  final Uint8List secret;
  final CloudProviderId provider;

  /// Название, которое видит пользователь (например, «Работа»).
  final String label;

  /// Максимальный размер файла в этой базе. Задаётся при создании,
  /// передаётся вместе с ключом и меняется через настройки базы в облаке
  /// (`VaultSettings`), поэтому одинаков на всех устройствах.
  final int maxFileSize;

  /// Шифруются ли записи и файлы в облаке. В базе без шифрования файлы
  /// лежат под своими настоящими именами и открываются прямо в облаке.
  final bool isEncrypted;

  VaultKey copyWith({String? label, int? maxFileSize}) => VaultKey(
    secret: secret,
    provider: provider,
    label: label ?? this.label,
    maxFileSize: maxFileSize ?? this.maxFileSize,
    isEncrypted: isEncrypted,
  );

  /// Один и тот же ключ, даже если локальные названия различаются.
  bool sameVaultAs(VaultKey other) =>
      provider == other.provider &&
      isEncrypted == other.isEncrypted &&
      listEquals(secret, other.secret);

  @override
  bool operator ==(Object other) =>
      other is VaultKey &&
      sameVaultAs(other) &&
      label == other.label &&
      maxFileSize == other.maxFileSize;

  @override
  int get hashCode => Object.hash(
    provider,
    label,
    maxFileSize,
    isEncrypted,
    Object.hashAll(secret),
  );
}
