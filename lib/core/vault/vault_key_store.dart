import 'dart:convert';

import '../persistence/key_value_store.dart';
import 'vault_key.dart';
import 'vault_key_codec.dart';

/// Список ключей баз, сохранённых на этом устройстве.
class VaultKeyStore {
  const VaultKeyStore(this._store, [this._codec = const VaultKeyCodec()]);

  static const String _storeKey = 'vault_keys';
  static const String _pinnedKey = 'pinned_vault_id';
  static const String _tagsKey = 'user_known_tags';

  final SecureKeyValueStore _store;
  final VaultKeyCodec _codec;

  Future<List<VaultKey>> loadAll() async {
    final raw = await _store.read(_storeKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return [
      for (final item in list) _codec.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> saveAll(List<VaultKey> keys) => _store.write(
    _storeKey,
    jsonEncode([for (final k in keys) _codec.toJson(k)]),
  );

  /// Идентификатор закреплённой доски на этом устройстве (если есть).
  Future<String?> loadPinnedId() => _store.read(_pinnedKey);

  /// Сохраняет или сбрасывает идентификатор закреплённой доски.
  Future<void> savePinnedId(String? id) =>
      id == null ? _store.delete(_pinnedKey) : _store.write(_pinnedKey, id);

  /// Загружает сохранённые теги пользователя на этом устройстве.
  Future<Set<String>> loadKnownTags() async {
    final raw = await _store.read(_tagsKey);
    if (raw == null) return const {};
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Сохраняет известные теги пользователя на этом устройстве.
  Future<void> saveKnownTags(Set<String> tags) => _store.write(
    _tagsKey,
    jsonEncode(tags.toList()),
  );
}
