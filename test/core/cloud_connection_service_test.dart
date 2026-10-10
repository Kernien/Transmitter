import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';

class FakeAdapter implements CloudProviderAdapter {
  String signInResult = 'creds-1';
  bool storageRejects = false;
  CredentialsChanged? lastListener;

  @override
  CloudProviderId get id => CloudProviderId.dropbox;

  @override
  bool get isConfigured => true;

  @override
  String get configurationHint => '';

  @override
  Future<String> signIn() async => signInResult;

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) {
    lastListener = onCredentialsChanged;
    if (storageRejects) return _RejectingStorage();
    return InMemoryCloudStorage();
  }
}

class _RejectingStorage extends InMemoryCloudStorage {
  @override
  Future<List<RemoteFile>> listFiles(String folder) async =>
      throw const StorageAuthException();
}

void main() {
  late FakeAdapter adapter;
  late InMemoryKeyValueStore store;
  late CloudConnectionService service;

  setUp(() {
    adapter = FakeAdapter();
    store = InMemoryKeyValueStore();
    service = CloudConnectionService(CloudProviderRegistry([adapter]), store);
  });

  test('connect сохраняет учётные данные, они переживают перезапуск', () async {
    await service.connect(CloudProviderId.dropbox);
    expect(service.isConnected(CloudProviderId.dropbox), isTrue);

    final restarted = CloudConnectionService(
      CloudProviderRegistry([adapter]),
      store,
    );
    await restarted.load();
    expect(restarted.isConnected(CloudProviderId.dropbox), isTrue);
  });

  test('если пробный запрос не прошёл, облако не подключается', () async {
    adapter.storageRejects = true;
    await expectLater(
      service.connect(CloudProviderId.dropbox),
      throwsA(isA<StorageAuthException>()),
    );
    expect(service.isConnected(CloudProviderId.dropbox), isFalse);
  });

  test('обновлённые токены сохраняются', () async {
    await service.connect(CloudProviderId.dropbox);
    service.storageFor(CloudProviderId.dropbox);
    await adapter.lastListener!('creds-2');
    expect(store.values.values, contains('creds-2'));
  });

  test('disconnect удаляет данные', () async {
    await service.connect(CloudProviderId.dropbox);
    await service.disconnect(CloudProviderId.dropbox);
    expect(service.isConnected(CloudProviderId.dropbox), isFalse);
    expect(store.values, isEmpty);
  });

  test('неподдерживаемое облако', () {
    expect(service.isSupported(CloudProviderId.mega), isFalse);
    expect(
      () => service.storageFor(CloudProviderId.mega),
      throwsA(isA<StorageAuthException>()),
    );
  });
}
