import 'dart:convert';
import 'dart:math';

import '../core/crypto/cipher.dart';
import '../core/crypto/vault_key_derivation.dart';
import '../core/storage/cloud_storage.dart';
import '../core/vault/vault_key.dart';

abstract interface class SubVaultsRemote {
  List<VaultKey>? cachedSubVaults(VaultKey parent);
  Future<List<VaultKey>> listSubVaults(VaultKey parent);
  Future<VaultKey> createSubVault(VaultKey parent, String label);
  Future<VaultKey> renameSubVault(
    VaultKey parent,
    VaultKey child,
    String label,
  );
  Future<VaultKey> setSubVaultMaxFileSize(
    VaultKey parent,
    VaultKey child,
    int maxFileSize,
  );
  Future<void> deleteSubVault(VaultKey parent, VaultKey child);
}

/// Отдельная запись на поддоску позволяет создавать их с разных устройств
/// одновременно. Ключи в каталог не записываются.
class SubVaultStore {
  SubVaultStore({
    required this.storage,
    required this.parent,
    required this.vaultId,
    required this.cipher,
    required this.derivation,
  });

  final CloudStorage storage;
  final VaultKey parent;
  final String vaultId;
  final Cipher cipher;
  final VaultKeyDerivation derivation;

  // Общая папка для каталога доски потребовала бы согласованного создания
  // на разных устройствах. Google Drive разрешает одноимённые папки.
  String get _prefix => 'sub-vault-v1-$vaultId-';

  Future<List<VaultKey>> list() async {
    final fileName = RegExp('^$_prefix([0-9a-f]{32})[.]bin\$');
    final files = await storage.listFiles('');
    final ids = <String>[
      for (final file in files) ?fileName.firstMatch(file.name)?.group(1),
    ];
    final loaded = await Future.wait(ids.map(_loadOne));
    final children = <VaultKey>[
      for (final child in loaded) ?child,
    ];
    return children
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  Future<VaultKey?> _loadOne(String id) async {
    try {
      final bytes = await storage.download('$_prefix$id.bin');
      final record = jsonDecode(utf8.decode(await cipher.decrypt(bytes)));
      if (record is! Map || record['id'] != id || record['label'] is! String) {
        return null;
      }
      final limit = record['limit'];
      if (limit is! int ||
          limit < VaultKey.minFileSize ||
          limit > VaultKey.absoluteMaxFileSize) {
        return null;
      }
      return await _key(id, record['label'] as String, limit);
    } catch (_) {
      // Пропускаем повреждённый файл записи поддоски, чтобы не ломать весь список.
      return null;
    }
  }

  Future<VaultKey> create(String label) async {
    final name = label.trim();
    if (name.isEmpty) throw ArgumentError.value(label, 'label');
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final child = await _key(id, name, parent.maxFileSize);
    await _writeRecord(id, name, child.maxFileSize);
    return child;
  }

  /// Обновляет название или лимит размера файла в записи поддоски.
  Future<void> update(VaultKey child) async {
    final name = child.label.trim();
    if (name.isEmpty) throw ArgumentError.value(child.label, 'label');
    final id = await _findChildId(child);
    if (id == null) return;
    await _writeRecord(id, name, child.maxFileSize);
  }

  /// Удаляет связь родительской доски с поддоской из облака.
  Future<void> delete(VaultKey child) async {
    final id = await _findChildId(child);
    if (id == null) return;
    await storage.delete('$_prefix$id.bin');
  }

  Future<String?> _findChildId(VaultKey child) async {
    final fileName = RegExp('^$_prefix([0-9a-f]{32})[.]bin\$');
    for (final file in await storage.listFiles('')) {
      final id = fileName.firstMatch(file.name)?.group(1);
      if (id == null) continue;
      final candidate = await _key(id, child.label, child.maxFileSize);
      if (candidate.sameVaultAs(child)) return id;
    }
    return null;
  }

  Future<void> _writeRecord(String id, String name, int limit) async {
    await storage.upload(
      '$_prefix$id.bin',
      await cipher.encrypt(
        utf8.encode(
          jsonEncode({'id': id, 'label': name, 'limit': limit}),
        ),
      ),
    );
  }

  Future<VaultKey> _key(String id, String label, int limit) async => VaultKey(
    secret: await derivation.subVaultSecret(parent.secret, id),
    provider: parent.provider,
    label: label,
    maxFileSize: limit,
    isEncrypted: parent.isEncrypted,
    accountId: parent.accountId,
    accountEmail: parent.accountEmail,
  );
}
