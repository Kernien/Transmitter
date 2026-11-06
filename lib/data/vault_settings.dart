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

/// Имя папки базы в облаке.
///
/// У зашифрованных баз это 32-символьный `vaultId` (`c5eea100…`).
/// У баз без шифрования папка называется так, как её назвал владелец, с
/// коротким кодом в квадратных скобках в конце (`Фото отпуска [c5ee]` или
/// `[c5ee]`, если названия нет):
/// - пользователю сразу видно свою папку в облаке;
/// - другие устройства находят папку по суффиксу `[c5ee]`, даже если её уже
///   переименовали на другом устройстве;
/// - при переименовании базы сама папка в облаке тоже переименовывается.
class PlainVaultFolder {
  const PlainVaultFolder._();

  static const int _tagLength = 4;

  static String tagOf(String vaultId) =>
      '[${vaultId.substring(0, _tagLength)}]';

  /// Целевое имя папки для названия [label] и идентификатора [vaultId].
  static String formatName(String label, String vaultId) {
    final tag = tagOf(vaultId);
    final clean = _sanitize(label);
    return clean.isEmpty ? tag : '$clean $tag';
  }

  /// Относится ли папка [folderName] к базе [vaultId] (по тегу `[xxxx]`
  /// или прежнему полному `vaultId`).
  static bool matches(String folderName, String vaultId) =>
      folderName == vaultId || folderName.endsWith(tagOf(vaultId));

  /// Находит существующую папку базы в корне облака (и при необходимости
  /// переименовывает её под текущее [label]) или возвращает имя новой папки.
  static Future<String> resolve(
    CloudStorage storage, {
    required String vaultId,
    required String label,
    bool renameToLabel = false,
  }) async {
    final target = formatName(label, vaultId);
    final folders = await storage.listFolders('');
    final existing =
        folders.where((f) => f.endsWith(tagOf(vaultId))).firstOrNull ??
        folders.where((f) => f == vaultId).firstOrNull;
    if (existing == null) return target;
    if (renameToLabel && existing != target) {
      await storage.renameFolder(existing, target);
      return target;
    }
    return existing;
  }

  static String _sanitize(String label) => label
      .replaceAll(RegExp(r'[\x00-\x1F\\/:*?"<>|\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Файл настроек базы в облаке: `<папка базы>/settings.bin`.
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
