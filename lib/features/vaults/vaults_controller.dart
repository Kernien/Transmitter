import 'package:flutter/foundation.dart';

import '../../core/storage/cloud_provider_id.dart';
import '../../core/vault/vault_key.dart';
import '../../core/vault/vault_key_codec.dart';
import '../../core/vault/vault_key_store.dart';

/// Список ключей баз на этом устройстве: создание, импорт, переименование,
/// удаление.
class VaultsController extends ChangeNotifier {
  VaultsController(this._store, [this._codec = const VaultKeyCodec()]);

  final VaultKeyStore _store;
  final VaultKeyCodec _codec;

  List<VaultKey> _vaults = const [];

  List<VaultKey> get vaults => List.unmodifiable(_vaults);

  Future<void> load() async {
    _vaults = await _store.loadAll();
    notifyListeners();
  }

  Future<VaultKey> create({
    required String label,
    required CloudProviderId provider,
  }) async {
    final key = VaultKey.generate(provider: provider, label: label.trim());
    await _save([..._vaults, key]);
    return key;
  }

  /// Добавляет ключ из строки или QR-кода. Если такой ключ уже есть,
  /// возвращает существующий. Бросает [FormatException] для неверной строки.
  Future<VaultKey> importCode(String code) async {
    final key = _codec.decode(code);
    for (final existing in _vaults) {
      if (existing.sameVaultAs(key)) return existing;
    }
    await _save([..._vaults, key]);
    return key;
  }

  String exportCode(VaultKey key) => _codec.encode(key);

  Future<void> rename(VaultKey key, String label) => _save([
    for (final k in _vaults)
      k.sameVaultAs(key) ? k.copyWith(label: label.trim()) : k,
  ]);

  /// Удаляет ключ только с этого устройства. Данные в облаке остаются.
  Future<void> remove(VaultKey key) =>
      _save(_vaults.where((k) => !k.sameVaultAs(key)).toList());

  Future<void> _save(List<VaultKey> next) async {
    await _store.saveAll(next);
    _vaults = next;
    notifyListeners();
  }
}
