import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_codec.dart';

/// Адаптер, который при каждом входе выдаёт новый аккаунт.
class _MultiAdapter implements CloudProviderAdapter {
  int _n = 0;
  final Map<String, InMemoryCloudStorage> storages = {};

  @override
  CloudProviderId get id => CloudProviderId.dropbox;

  @override
  bool get isConfigured => true;

  @override
  Future<String> signIn() async => 'creds-${++_n}';

  @override
  Future<CloudAccountProfile?> fetchProfile(String credentials) async =>
      CloudAccountProfile(
        email: '$credentials@mail.test',
        displayName: 'User $credentials',
      );

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) => storages.putIfAbsent(credentials, InMemoryCloudStorage.new);
}

void main() {
  late _MultiAdapter adapter;
  late InMemoryKeyValueStore store;
  late CloudConnectionService service;

  setUp(() {
    adapter = _MultiAdapter();
    store = InMemoryKeyValueStore();
    service = CloudConnectionService(CloudProviderRegistry([adapter]), store);
  });

  test('можно подключить два аккаунта одного облака', () async {
    final a = await service.connect(CloudProviderId.dropbox);
    final b = await service.connect(CloudProviderId.dropbox);
    expect(a.id, isNot(b.id));
    expect(service.accountsFor(CloudProviderId.dropbox), hasLength(2));
    expect(a.email, 'creds-1@mail.test');
    expect(
      service.storageFor(CloudProviderId.dropbox, accountId: a.id),
      isNot(same(service.storageFor(CloudProviderId.dropbox, accountId: b.id))),
    );
  });

  test('аккаунты переживают перезапуск', () async {
    await service.connect(CloudProviderId.dropbox);
    await service.connect(CloudProviderId.dropbox);
    final restarted = CloudConnectionService(
      CloudProviderRegistry([adapter]),
      store,
    );
    await restarted.load();
    expect(restarted.accountsFor(CloudProviderId.dropbox), hasLength(2));
  });

  test('данные прежнего формата переносятся в аккаунт', () async {
    await store.write('cloud_credentials.dropbox', 'old-creds');
    await service.load();
    final accounts = service.accountsFor(CloudProviderId.dropbox);
    expect(accounts, hasLength(1));
    expect(service.isConnected(CloudProviderId.dropbox), isTrue);
    expect(
      () => service.storageFor(CloudProviderId.dropbox),
      returnsNormally,
    );
  });

  test('выход из одного аккаунта не трогает другой', () async {
    final a = await service.connect(CloudProviderId.dropbox);
    final b = await service.connect(CloudProviderId.dropbox);
    await service.disconnectAccount(a.id);
    expect(service.accountById(a.id), isNull);
    expect(service.accountById(b.id), isNotNull);
    expect(service.isConnected(CloudProviderId.dropbox), isTrue);
    await service.disconnectAccount(b.id);
    expect(service.isConnected(CloudProviderId.dropbox), isFalse);
  });

  test('повторный вход в тот же аккаунт не создаёт дубликат', () async {
    final first = await service.connect(CloudProviderId.dropbox);
    adapter._n = 0; // тот же creds-1 → тот же email
    final again = await service.connect(CloudProviderId.dropbox);
    expect(again.id, first.id);
    expect(service.accountsFor(CloudProviderId.dropbox), hasLength(1));
  });

  test('переименование аккаунта', () async {
    final a = await service.connect(CloudProviderId.dropbox);
    await service.renameAccount(a.id, 'Рабочий');
    expect(service.accountById(a.id)!.displayName, 'Рабочий');
  });

  test('findAccountForVault: по id, по почте, иначе первый', () async {
    final a = await service.connect(CloudProviderId.dropbox);
    final b = await service.connect(CloudProviderId.dropbox);
    VaultKey key({String? id, String? email}) => VaultKey.generate(
      provider: CloudProviderId.dropbox,
      label: 'x',
      accountId: id,
      accountEmail: email,
    );
    expect(service.findAccountForVault(key(id: b.id))!.id, b.id);
    expect(service.findAccountForVault(key(email: b.email))!.id, b.id);
    expect(service.findAccountForVault(key())!.id, a.id);
  });

  test('ключ хранит аккаунт; старые ключи без него читаются', () {
    const codec = VaultKeyCodec();
    final key = VaultKey.generate(
      provider: CloudProviderId.dropbox,
      label: 'x',
      accountId: 'acc1',
      accountEmail: 'me@mail.test',
    );
    final back = codec.decode(codec.encode(key));
    expect(back.accountId, 'acc1');
    expect(back.accountEmail, 'me@mail.test');

    final plain = VaultKey.generate(provider: CloudProviderId.dropbox, label: 'y');
    expect(codec.toJson(plain).containsKey('a'), isFalse);
    expect(codec.decode(codec.encode(plain)).accountId, isNull);
  });
}