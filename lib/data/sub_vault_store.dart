import 'dart:convert';
import 'dart:math';

import '../core/crypto/cipher.dart';
import '../core/crypto/vault_key_derivation.dart';
import '../core/storage/cloud_storage.dart';
import '../core/vault/vault_key.dart';

abstract interface class SubVaultsRemote {
  Future<List<VaultKey>> listSubVaults(VaultKey parent);
  Future<VaultKey> createSubVault(VaultKey parent, String label);
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
    final children = <VaultKey>[];
    final fileName = RegExp('^$_prefix([0-9a-f]{32})[.]bin\$');
    for (final file in await storage.listFiles('')) {
      final id = fileName.firstMatch(file.name)?.group(1);
      if (id == null) continue;
      final bytes = await storage.download(file.name);
      final record = jsonDecode(utf8.decode(await cipher.decrypt(bytes)));
      if (record is! Map || record['id'] != id || record['label'] is! String) {
        throw const FormatException('Invalid sub-vault record');
      }
      final limit = record['limit'];
      if (limit is! int ||
          limit < VaultKey.minFileSize ||
          limit > VaultKey.absoluteMaxFileSize) {
        throw const FormatException('Invalid sub-vault file size limit');
      }
      children.add(await _key(id, record['label'] as String, limit));
    }
    return children
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
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
    await storage.upload(
      '$_prefix$id.bin',
      await cipher.encrypt(
        utf8.encode(
          jsonEncode({'id': id, 'label': name, 'limit': child.maxFileSize}),
        ),
      ),
    );
    return child;
  }

  Future<VaultKey> _key(String id, String label, int limit) async => VaultKey(
    secret: await derivation.subVaultSecret(parent.secret, id),
    provider: parent.provider,
    label: label,
    maxFileSize: limit,
    accountId: parent.accountId,
    accountEmail: parent.accountEmail,
  );
}
