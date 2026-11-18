import 'package:flutter/foundation.dart';

import 'cloud_provider_id.dart';

/// Подключённый аккаунт облачного хранилища на этом устройстве.
///
/// У одного провайдера ([provider]) может быть несколько аккаунтов
/// (например, личный и рабочий Google Drive или несколько аккаунтов MEGA).
@immutable
class CloudAccount {
  const CloudAccount({
    required this.id,
    required this.provider,
    required this.label,
    this.email,
  });

  /// Уникальный постоянный идентификатор аккаунта на устройстве.
  final String id;

  /// Провайдер облачного хранилища.
  final CloudProviderId provider;

  /// Пользовательское или автоматически присвоенное имя (например, «Рабочий»).
  final String label;

  /// Адрес электронной почты аккаунта в облаке (если известен).
  final String? email;

  /// Отображаемое имя аккаунта в интерфейсе.
  String get displayName {
    if (label.isNotEmpty) return label;
    if (email != null && email!.isNotEmpty) return email!;
    return provider.title;
  }

  CloudAccount copyWith({
    String? label,
    String? email,
  }) => CloudAccount(
    id: id,
    provider: provider,
    label: label ?? this.label,
    email: email ?? this.email,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider.code,
    'label': label,
    if (email != null) 'email': email,
  };

  factory CloudAccount.fromJson(Map<String, dynamic> json) => CloudAccount(
    id: json['id'] as String,
    provider: CloudProviderId.fromCode(json['provider'] as String),
    label: json['label'] as String? ?? '',
    email: json['email'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudAccount &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          provider == other.provider &&
          label == other.label &&
          email == other.email;

  @override
  int get hashCode => Object.hash(id, provider, label, email);

  @override
  String toString() =>
      'CloudAccount(id: $id, provider: ${provider.code}, label: $label, email: $email)';
}
