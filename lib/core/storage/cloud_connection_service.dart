import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../errors/app_error.dart';
import '../persistence/key_value_store.dart';
import '../vault/vault_key.dart';
import 'cloud_account.dart';
import 'cloud_provider_adapter.dart';
import 'cloud_provider_id.dart';
import 'cloud_storage.dart';

/// Хранит учётные данные облаков на этом устройстве и выдаёт готовые
/// [CloudStorage]. Поддерживает несколько аккаунтов одного облака.
///
/// Учётные данные никогда не попадают в ключ базы: каждое устройство входит
/// в облако само.
class CloudConnectionService extends ChangeNotifier {
  CloudConnectionService(this._registry, this._store);

  final CloudProviderRegistry _registry;
  final SecureKeyValueStore _store;

  final List<CloudAccount> _accounts = [];
  final Map<String, String> _credentials = {};
  final Map<String, int> _epochs = {};
  final Map<CloudProviderId, int> _providerEpochs = {};

  static const String _accountsStoreKey = 'cloud_accounts';
  static String _legacyStoreKey(CloudProviderId id) =>
      'cloud_credentials.${id.code}';
  static String _accountCredentialsStoreKey(String accountId) =>
      'cloud_account_credentials.$accountId';

  /// Загружает сохранённые аккаунты облаков с защищённого хранилища.
  Future<void> load() async {
    _accounts.clear();
    _credentials.clear();

    final raw = await _store.read(_accountsStoreKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          final account = CloudAccount.fromJson(item as Map<String, dynamic>);
          final creds =
              await _store.read(_accountCredentialsStoreKey(account.id)) ??
              await _store.read(_legacyStoreKey(account.provider));
          if (creds != null) {
            _accounts.add(account);
            _credentials[account.id] = creds;
          }
        }
      } catch (_) {
        // При повреждении списка пробуем прочесть старый формат.
      }
    }

    // Если аккаунтов в новом формате не найдено — переносим данные из прежнего формата.
    if (_accounts.isEmpty) {
      for (final id in CloudProviderId.values) {
        final creds = await _store.read(_legacyStoreKey(id));
        if (creds != null) {
          final accountId = 'legacy_${id.code}';
          final account = CloudAccount(
            id: accountId,
            provider: id,
            label: id.title,
          );
          _accounts.add(account);
          _credentials[accountId] = creds;
          await _store.write(_accountCredentialsStoreKey(accountId), creds);
        }
      }
      if (_accounts.isNotEmpty) {
        await _saveAccountsList();
      }
    }

    notifyListeners();
  }

  /// Все подключённые аккаунты облаков на этом устройстве.
  List<CloudAccount> get accounts => List.unmodifiable(_accounts);

  /// Аккаунты конкретного провайдера.
  List<CloudAccount> accountsFor(CloudProviderId id) =>
      _accounts.where((a) => a.provider == id).toList();

  /// Аккаунт по его уникальному идентификатору на этом устройстве.
  CloudAccount? accountById(String? id) {
    if (id == null) return null;
    return _accounts.where((a) => a.id == id).firstOrNull;
  }

  /// Находит подходящий аккаунт для базы.
  /// Сначала по [VaultKey.accountId], затем по совпадению [VaultKey.accountEmail],
  /// а если соответствия нет — берётся первый подключённый аккаунт этого провайдера.
  CloudAccount? findAccountForVault(VaultKey vault) {
    if (vault.accountId != null) {
      final found = accountById(vault.accountId);
      if (found != null) return found;
    }
    if (vault.accountEmail != null && vault.accountEmail!.isNotEmpty) {
      final byEmail = _accounts
          .where(
            (a) =>
                a.provider == vault.provider && a.email == vault.accountEmail,
          )
          .firstOrNull;
      if (byEmail != null) return byEmail;
    }
    final providerAccounts = accountsFor(vault.provider);
    return providerAccounts.firstOrNull;
  }

  bool isSupported(CloudProviderId id) => _registry.supports(id);

  /// Подключён ли провайдер (или конкретный аккаунт, если передан [accountId]).
  bool isConnected(CloudProviderId id, {String? accountId}) {
    if (accountId != null) {
      return _accounts.any((a) => a.id == accountId);
    }
    return _accounts.any((a) => a.provider == id);
  }

  /// Меняется при каждом входе в облако и выходе из него (но не при
  /// обновлении токена) — открытые сессии баз по нему понимают, что их
  /// хранилище устарело.
  int connectionEpoch(CloudProviderId id, [String? accountId]) {
    if (accountId != null) {
      return _epochs[accountId] ?? _providerEpochs[id] ?? 0;
    }
    return _providerEpochs[id] ?? 0;
  }

  CloudProviderAdapter adapterFor(CloudProviderId id) =>
      _registry.adapterFor(id);

  /// Проводит вход, проверяет доступ пробным запросом и сохраняет аккаунт.
  ///
  /// Вызывайте прямо из обработчика нажатия (см. [CloudProviderAdapter.signIn]).
  Future<CloudAccount> connect(CloudProviderId id, {String? customLabel}) {
    final adapter = _registry.adapterFor(id);
    return _finishConnect(
      id,
      adapter,
      adapter.signIn(),
      customLabel: customLabel,
    );
  }

  /// Вход по почте и паролю (см. [PasswordCloudAdapter]).
  Future<CloudAccount> connectWithPassword(
    CloudProviderId id, {
    required String email,
    required String password,
    String? secondFactorCode,
    String? customLabel,
  }) {
    final adapter = _registry.adapterFor(id) as PasswordCloudAdapter;
    return _finishConnect(
      id,
      adapter,
      adapter.signInWithPassword(
        email: email,
        password: password,
        secondFactorCode: secondFactorCode,
      ),
      email: email,
      customLabel: customLabel,
    );
  }

  Future<CloudAccount> _finishConnect(
    CloudProviderId id,
    CloudProviderAdapter adapter,
    Future<String> signIn, {
    String? email,
    String? customLabel,
  }) async {
    var credentials = await signIn;
    final storage = adapter.createStorage(
      credentials,
      onCredentialsChanged: (updated) async => credentials = updated,
    );
    await storage.listFiles('');

    final profile = await adapter.fetchProfile(credentials);
    final accountEmail = email ?? profile?.email;
    final accountName = customLabel?.trim().isNotEmpty == true
        ? customLabel!.trim()
        : profile?.displayName ?? accountEmail ?? _defaultAccountLabel(id);

    // Если аккаунт с таким же email уже был подключён, обновляем его
    var existingIndex = (accountEmail != null && accountEmail.isNotEmpty)
        ? _accounts.indexWhere(
            (a) => a.provider == id && a.email == accountEmail,
          )
        : -1;
    // Почта неизвестна: единственный аккаунт облака без почты — это он же
    // (повторный вход), а не новый.
    if (existingIndex == -1 && (accountEmail == null || accountEmail.isEmpty)) {
      final noEmail = [
        for (var i = 0; i < _accounts.length; i++)
          if (_accounts[i].provider == id && (_accounts[i].email ?? '').isEmpty) i,
      ];
      if (noEmail.length == 1) existingIndex = noEmail.single;
    }

    final CloudAccount account;
    if (existingIndex != -1) {
      final existing = _accounts[existingIndex];
      account = existing.copyWith(
        email: accountEmail,
        label: existing.label.isNotEmpty ? existing.label : accountName,
      );
      _accounts[existingIndex] = account;
    } else {
      final rnd = Random().nextInt(10000);
      final accountId =
          'acc_${id.code}_${DateTime.now().millisecondsSinceEpoch}_$rnd';
      account = CloudAccount(
        id: accountId,
        provider: id,
        label: accountName,
        email: accountEmail,
      );
      _accounts.add(account);
    }

    _credentials[account.id] = credentials;
    _epochs[account.id] = (_epochs[account.id] ?? 0) + 1;
    _providerEpochs[id] = (_providerEpochs[id] ?? 0) + 1;

    await _store.write(_accountCredentialsStoreKey(account.id), credentials);
    final firstForProvider = _accounts.firstWhere((a) => a.provider == id);
    if (firstForProvider.id == account.id) {
      await _store.write(_legacyStoreKey(id), credentials);
    }
    await _saveAccountsList();
    notifyListeners();
    return account;
  }

  String _defaultAccountLabel(CloudProviderId id) {
    final count = accountsFor(id).length;
    return count == 0 ? id.title : '${id.title} (${count + 1})';
  }

  /// Отключает конкретный аккаунт.
  Future<void> disconnectAccount(String accountId) async {
    final account = accountById(accountId);
    if (account == null) return;

    _accounts.removeWhere((a) => a.id == accountId);
    _credentials.remove(accountId);
    _epochs[accountId] = (_epochs[accountId] ?? 0) + 1;
    _providerEpochs[account.provider] =
        (_providerEpochs[account.provider] ?? 0) + 1;

    await _store.delete(_accountCredentialsStoreKey(accountId));
    final remaining = accountsFor(account.provider);
    if (remaining.isEmpty) {
      await _store.delete(_legacyStoreKey(account.provider));
    } else {
      final newFirst = remaining.first;
      final newFirstCreds = _credentials[newFirst.id];
      if (newFirstCreds != null) {
        await _store.write(_legacyStoreKey(account.provider), newFirstCreds);
      }
    }
    await _saveAccountsList();
    notifyListeners();
  }

  /// Отключает все аккаунты указанного облака.
  Future<void> disconnect(CloudProviderId id) async {
    final toRemove = accountsFor(id);
    for (final account in toRemove) {
      _accounts.removeWhere((a) => a.id == account.id);
      _credentials.remove(account.id);
      _epochs[account.id] = (_epochs[account.id] ?? 0) + 1;
      await _store.delete(_accountCredentialsStoreKey(account.id));
    }
    _providerEpochs[id] = (_providerEpochs[id] ?? 0) + 1;
    await _store.delete(_legacyStoreKey(id));
    await _saveAccountsList();
    notifyListeners();
  }

  /// Переименовывает аккаунт на этом устройстве.
  Future<void> renameAccount(String accountId, String newLabel) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;
    _accounts[index] = _accounts[index].copyWith(label: newLabel.trim());
    await _saveAccountsList();
    notifyListeners();
  }

  /// Возвращает [CloudStorage] для облака или конкретного аккаунта.
  CloudStorage storageFor(CloudProviderId id, {String? accountId}) {
    CloudAccount? account;
    if (accountId != null) {
      account = accountById(accountId);
      if (account == null) {
        throw const StorageAuthException(ErrorCode.cloudNotConnected);
      }
    } else {
      final providerAccounts = accountsFor(id);
      if (providerAccounts.isEmpty) {
        throw const StorageAuthException(ErrorCode.cloudNotConnected);
      }
      account = providerAccounts.first;
    }

    final credentials = _credentials[account.id];
    if (credentials == null) {
      throw const StorageAuthException(ErrorCode.cloudNotConnected);
    }

    final targetAccountId = account.id;
    return _registry
        .adapterFor(account.provider)
        .createStorage(
          credentials,
          onCredentialsChanged: (updated) =>
              _onAccountCredentialsChanged(targetAccountId, updated),
        );
  }

  Future<void> _onAccountCredentialsChanged(
    String accountId,
    String credentials,
  ) async {
    _credentials[accountId] = credentials;
    await _store.write(_accountCredentialsStoreKey(accountId), credentials);
    final account = accountById(accountId);
    if (account != null) {
      final first = accountsFor(account.provider).firstOrNull;
      if (first?.id == accountId) {
        await _store.write(_legacyStoreKey(account.provider), credentials);
      }
    }
  }

  Future<void> _saveAccountsList() async {
    if (_accounts.isEmpty) {
      await _store.delete(_accountsStoreKey);
      return;
    }
    await _store.write(
      _accountsStoreKey,
      jsonEncode([for (final a in _accounts) a.toJson()]),
    );
  }
}
