import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/app/vault_session_factory.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/reader_key.dart';
import 'package:transmitter/core/vault/vault_key.dart';

import '../support/sharing_cloud.dart';

/// Облако в памяти, которое считает скачивания.
class CountingCloud extends InMemoryCloudStorage {
  int downloads = 0;

  @override
  Future<Uint8List> download(String path) {
    downloads++;
    return super.download(path);
  }
}

class FakeAdapter implements CloudProviderAdapter {
  FakeAdapter(this.cloud);

  final CloudStorage cloud;

  @override
  CloudProviderId get id => CloudProviderId.dropbox;

  @override
  bool get isConfigured => true;

  @override
  Future<String> signIn() async => 'creds';

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) => cloud;
}

void main() {
  late CountingCloud cloud;
  late CloudConnectionService connections;
  late String deviceName;
  late VaultSessionFactory sessions;
  final key = VaultKey(
    secret: List<int>.filled(32, 9),
    provider: CloudProviderId.dropbox,
    label: 'База',
  );

  setUp(() async {
    cloud = CountingCloud();
    connections = CloudConnectionService(
      CloudProviderRegistry([FakeAdapter(cloud)]),
      InMemoryKeyValueStore(),
    );
    await connections.connect(CloudProviderId.dropbox);
    deviceName = 'Телефон';
    sessions = VaultSessionFactory(
      connections: connections,
      deviceName: () => deviceName,
    );
  });

  test('повторный вход в ленту — те же записи без загрузки', () async {
    final first = await sessions.open(key);
    expect(first.cachedPosts, isNull);
    await first.sendText('один');
    await first.sendText('два');
    await first.fetchPosts();

    final again = await sessions.open(key);
    expect(identical(again, first), isTrue);
    expect(again.cachedPosts!.map((p) => p.text), ['один', 'два']);

    final before = cloud.downloads;
    await again.fetchPosts();
    expect(cloud.downloads, before, reason: 'новых записей нет — не качаем');
  });

  test('после нового входа в облако сессия создаётся заново', () async {
    final first = await sessions.open(key);
    await connections.connect(CloudProviderId.dropbox);
    expect(identical(await sessions.open(key), first), isFalse);
  });

  test('после смены имени устройства — новая сессия', () async {
    final first = await sessions.open(key);
    deviceName = 'Ноутбук';
    final renamed = await sessions.open(key);
    expect(identical(renamed, first), isFalse);
    expect((await renamed.sendText('x')).senderDevice, 'Ноутбук');
  });

  test('неудачное открытие не запоминается', () async {
    await connections.disconnect(CloudProviderId.dropbox);
    expect(sessions.open(key), throwsA(isA<StorageAuthException>()));
    await Future<void>.delayed(Duration.zero);
    await connections.connect(CloudProviderId.dropbox);
    expect(await sessions.open(key), isNotNull);
  });

  test('доска у читателя открывается одна и та же', () {
    final boards = VaultSessionFactory(
      connections: connections,
      deviceName: () => deviceName,
      readers: {CloudProviderId.dropbox: SharingCloudReader(SharingCloud())},
    );
    final board = ReaderKey(
      provider: CloudProviderId.dropbox,
      label: 'Доска',
      locator: 'pub:x',
      encryptionKey: List<int>.filled(32, 1),
      ownerPublicKey: List<int>.filled(32, 2),
    );
    expect(
      identical(boards.openAsReader(board), boards.openAsReader(board)),
      isTrue,
    );
  });
}
