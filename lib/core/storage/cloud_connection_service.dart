import 'package:flutter/foundation.dart';

import '../errors/app_error.dart';
import '../persistence/key_value_store.dart';
import 'cloud_provider_adapter.dart';
import 'cloud_provider_id.dart';
import 'cloud_storage.dart';

/// Хранит учётные данные облаков на этом устройстве и выдаёт готовые
/// [CloudStorage].
///
/// Учётные данные никогда не попадают в ключ базы: каждое устройство входит
/// в облако само.
class CloudConnectionService extends ChangeNotifier {
  CloudConnectionService(this._registry, this._store);

  final CloudProviderRegistry _registry;
  final SecureKeyValueStore _store;
  final Map<CloudProviderId, String> _credentials = {};

  static String _storeKey(CloudProviderId id) => 'cloud_credentials.${id.code}';

  Future<void> load() async {
    for (final id in CloudProviderId.values) {
      final value = await _store.read(_storeKey(id));
      if (value != null) _credentials[id] = value;
    }
    notifyListeners();
  }

  bool isSupported(CloudProviderId id) => _registry.supports(id);

  bool isConnected(CloudProviderId id) => _credentials.containsKey(id);

  CloudProviderAdapter adapterFor(CloudProviderId id) =>
      _registry.adapterFor(id);

  /// Проводит вход, проверяет доступ пробным запросом и сохраняет данные.
  ///
  /// Вызывайте прямо из обработчика нажатия (см. [CloudProviderAdapter.signIn]).
  Future<void> connect(CloudProviderId id) async {
    final adapter = _registry.adapterFor(id);
    var credentials = await adapter.signIn();
    final storage = adapter.createStorage(
      credentials,
      onCredentialsChanged: (updated) async => credentials = updated,
    );
    await storage.listFiles('');
    await _save(id, credentials);
  }

  Future<void> disconnect(CloudProviderId id) async {
    await _store.delete(_storeKey(id));
    _credentials.remove(id);
    notifyListeners();
  }

  CloudStorage storageFor(CloudProviderId id) {
    final credentials = _credentials[id];
    if (credentials == null) {
      throw const StorageAuthException(ErrorCode.cloudNotConnected);
    }
    return _registry
        .adapterFor(id)
        .createStorage(
          credentials,
          onCredentialsChanged: (updated) => _save(id, updated),
        );
  }

  Future<void> _save(CloudProviderId id, String credentials) async {
    await _store.write(_storeKey(id), credentials);
    _credentials[id] = credentials;
    notifyListeners();
  }
}
