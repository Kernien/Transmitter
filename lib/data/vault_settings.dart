import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/crypto/cipher.dart';
import '../core/storage/cloud_storage.dart';
import '../core/vault/vault_key.dart';

/// Настройки базы, общие для всех её устройств: название и лимит размера
/// файла. Хранятся в облаке рядом с записями, зашифрованными ключом базы.
@immutable
class VaultSettings {
  const VaultSettings({
    required this.label,
    required this.maxFileSize,
    required this.updatedAt,
  });

  final String label;
  final int maxFileSize;
  final DateTime updatedAt;

  /// Отличаются ли настройки от того, что записано в ключе на устройстве.
  bool differsFrom(VaultKey key) =>
      label != key.label || maxFileSize != key.maxFileSize;

  Map<String, Object> toJson() => {
    'v': 1,
    'label': label,
    'm': maxFileSize,
    'ts': updatedAt.toUtc().toIso8601String(),
  };

  /// Бросает [FormatException], если данные не похожи на настройки.
  factory VaultSettings.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final size = json['m'];
    final ts = json['ts'];
    if (label is! String ||
        size is! int ||
        ts is! String ||
        size < VaultKey.maxFileSizeOptions.first ||
        size > VaultKey.absoluteMaxFileSize) {
      throw const FormatException('Invalid vault settings');
    }
    return VaultSettings(
      label: label,
      maxFileSize: size,
      updatedAt: DateTime.parse(ts),
    );
  }
}

/// Файл настроек базы в облаке: `<vaultId>/settings.bin`.
///
/// Его нет, пока настройки ни разу не меняли (у старых баз тоже): тогда
/// действуют название и лимит из ключа.
class VaultSettingsStore {
  VaultSettingsStore({
    required this._storage,
    required this._vaultId,
    required this._cipher,
  });

  final CloudStorage _storage;
  final String _vaultId;
  String get _path => '$_vaultId/settings.bin';
  final Cipher _cipher;

  /// `null`, если настроек в облаке нет (или файл повреждён).
  Future<VaultSettings?> load() async {
    final Uint8List encrypted;
    try {
      encrypted = await _storage.download(_path);
    } on StorageNotFoundException {
      return null;
    }
    try {
      final json = jsonDecode(utf8.decode(await _cipher.decrypt(encrypted)));
      return VaultSettings.fromJson(json as Map<String, dynamic>);
    } on Object catch (e) {
      // Повреждённый файл не должен ломать базу: остаются настройки ключа.
      debugPrint('Vault settings unreadable: $e');
      return null;
    }
  }

  Future<void> save(VaultSettings settings) async {
    // Папки базы ещё может не быть: на этом устройстве её не открывали.
    await _storage.ensureFolder(_vaultId);
    await _storage.upload(
      _path,
      await _cipher.encrypt(utf8.encode(jsonEncode(settings.toJson()))),
    );
  }
}

/// Доступ к настройкам баз в облаке по ключу базы.
abstract interface class VaultSettingsRemote {
  /// `null`, если облако базы не подключено или настроек в нём нет.
  Future<VaultSettings?> loadSettings(VaultKey key);

  /// Бросает ошибку облака (например, оно не подключено).
  Future<void> saveSettings(VaultKey key, VaultSettings settings);
}
