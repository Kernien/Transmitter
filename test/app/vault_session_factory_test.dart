import 'dart:convert';
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
import 'package:transmitter/core/vault/vault_key_codec.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';
import 'package:transmitter/features/vaults/vaults_controller.dart';

import '../support/sharing_cloud.dart';

/// Облако в памяти, которое считает скачивания.
class CountingCloud extends InMemoryCloudStorage {
  int downloads = 0;

  @override
  Future<Uint8List> download(String path, {ProgressCallback? onProgress}) {
    downloads++;
    return super.download(path, onProgress: onProgress);
  }
}

class FakeAdapter implements CloudProviderAdapter {
  FakeAdapter(this.cloud, {this.id = CloudProviderId.dropbox});

  final CloudStorage cloud;

  @override
  final CloudProviderId id;

  @override
  bool get isConfigured => true;

  @override
  Future<String> signIn() async => 'creds';

  @override
  Future<CloudAccountProfile?> fetchProfile(String credentials) async => null;

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

  group('настройки базы — общие для её устройств', () {
    /// Устройство: свои ключи на устройстве, общее облако.
    Future<VaultsController> device() async {
      final controller = VaultsController(
        VaultKeyStore(InMemoryKeyValueStore()),
        settings: sessions,
      );
      await controller.load();
      await controller.importCode(const VaultKeyCodec().encode(key));
      return controller;
    }

    test('название и лимит доходят до другого устройства', () async {
      final phone = await device();
      final laptop = await device();

      await phone.rename(phone.vaults.single, '  Работа ');
      await phone.setMaxFileSize(phone.vaults.single, 50 * 1024 * 1024);
      expect(phone.vaults.single.label, 'Работа');
      expect(laptop.vaults.single.label, 'База', reason: 'ещё не обновлялся');

      await laptop.refreshSettings();
      expect(laptop.vaults.single.label, 'Работа');
      expect(laptop.vaults.single.maxFileSize, 50 * 1024 * 1024);
      // Новая сессия ленты — уже с новым лимитом.
      expect(
        (await sessions.open(laptop.vaults.single)).maxFileSize,
        50 * 1024 * 1024,
      );

      // В облаке — один зашифрованный файл рядом с записями.
      final settings = cloud.files.entries.where(
        (e) => e.key.endsWith('/settings.bin'),
      );
      expect(settings, hasLength(1));
      expect(
        utf8.decode(settings.single.value, allowMalformed: true),
        isNot(contains('Работа')),
      );
    });

    test('без настроек в облаке остаётся то, что в ключе', () async {
      final laptop = await device();
      await laptop.refreshSettings();
      expect(laptop.vaults.single, key);
    });

    test('облако не подключено — изменение не проходит', () async {
      final phone = await device();
      await connections.disconnect(CloudProviderId.dropbox);
      await expectLater(
        phone.rename(phone.vaults.single, 'Новое'),
        throwsA(isA<StorageAuthException>()),
      );
      expect(phone.vaults.single.label, 'База');
      // Обновление без облака просто ничего не делает.
      await phone.refreshSettings();
      expect(phone.vaults.single.label, 'База');
    });

    test('повреждённый файл настроек не ломает базу', () async {
      final phone = await device();
      await phone.rename(phone.vaults.single, 'Работа');
      final path = cloud.files.keys.singleWhere(
        (p) => p.endsWith('/settings.bin'),
      );
      cloud.files[path]![20] ^= 0xFF;
      final laptop = await device();
      await laptop.refreshSettings();
      expect(laptop.vaults.single.label, 'База');
    });

    test('база без шифрования пишет файлы и настройки в открытом виде', () async {
      final plainKey = VaultKey(
        secret: List<int>.filled(32, 7),
        provider: CloudProviderId.dropbox,
        label: 'Общая',
        isEncrypted: false,
      );
      final repo = await sessions.open(plainKey);
      await repo.sendFile(
        fileName: 'План работ.txt',
        bytes: Uint8List.fromList(utf8.encode('1. Сделать')),
      );
      // Папка называется именем доски + коротким тегом: «Общая [xxxx]».
      final initialFile = cloud.files.keys.singleWhere(
        (k) => k.endsWith('/files/План работ.txt'),
      );
      expect(initialFile, startsWith('Общая ['));

      final controller = VaultsController(
        VaultKeyStore(InMemoryKeyValueStore()),
        settings: sessions,
      );
      await controller.load();
      await controller.importCode(const VaultKeyCodec().encode(plainKey));
      await controller.rename(controller.vaults.single, 'Общая папка');

      // После переименования папка в облаке тоже переименовалась в «Общая папка [xxxx]»,
      // а файл внутри неё остался на месте.
      final renamedFile = cloud.files.keys.singleWhere(
        (k) => k.endsWith('/files/План работ.txt'),
      );
      expect(renamedFile, startsWith('Общая папка ['));

      final settingsBytes = cloud.files.entries
          .singleWhere((e) => e.key.endsWith('/settings.bin'))
          .value;
      expect(utf8.decode(settingsBytes), contains('Общая папка'));

      // Второе устройство со старым ключом («Общая») находит переименованную
      // папку по тегу `[xxxx]` и видит файл и новые настройки.
      final otherSessions = VaultSessionFactory(
        connections: connections,
        deviceName: () => 'Ноутбук',
      );
      final otherDevice = VaultsController(
        VaultKeyStore(InMemoryKeyValueStore()),
        settings: otherSessions,
      );
      await otherDevice.load();
      await otherDevice.importCode(const VaultKeyCodec().encode(plainKey));
      final otherRepo = await otherSessions.open(otherDevice.vaults.single);
      final posts = await otherRepo.fetchPosts();
      expect(posts.single.attachment!.fileName, 'План работ.txt');
      await otherDevice.refreshSettings();
      expect(otherDevice.vaults.single.label, 'Общая папка');
    });

    test('управление поддосками: кэширование, создание, переименование, удаление', () async {
      expect(sessions.cachedSubVaults(key), isNull);
      final initial = await sessions.listSubVaults(key);
      expect(initial, isEmpty);
      expect(sessions.cachedSubVaults(key), isEmpty);

      final created = await sessions.createSubVault(key, 'Поддоска 1');
      expect(created.label, 'Поддоска 1');
      expect(sessions.cachedSubVaults(key)?.map((k) => k.label), ['Поддоска 1']);

      final renamed = await sessions.renameSubVault(key, created, 'Поддоска переименована');
      expect(renamed.label, 'Поддоска переименована');
      expect(sessions.cachedSubVaults(key)?.single.label, 'Поддоска переименована');

      final withNewLimit = await sessions.setSubVaultMaxFileSize(
        key,
        renamed,
        100 * 1024 * 1024,
      );
      expect(withNewLimit.maxFileSize, 100 * 1024 * 1024);
      expect(
        sessions.cachedSubVaults(key)?.single.maxFileSize,
        100 * 1024 * 1024,
      );

      await sessions.deleteSubVault(key, withNewLimit);
      expect(sessions.cachedSubVaults(key), isEmpty);
      expect(await sessions.listSubVaults(key), isEmpty);
    });

    test('поддоски для открытой базы создаются с PlaintextCipher и isEncrypted = false', () async {
      final plainKey = VaultKey(
        secret: List<int>.filled(32, 7),
        provider: CloudProviderId.dropbox,
        label: 'Открытая доска',
        isEncrypted: false,
      );

      final child = await sessions.createSubVault(plainKey, 'Вложенная');
      expect(child.isEncrypted, isFalse);
      expect(child.label, 'Вложенная');

      final list = await sessions.listSubVaults(plainKey);
      expect(list.single.isEncrypted, isFalse);
      expect(list.single.label, 'Вложенная');
    });

    test('P2P доска открывается без учетных записей и отправляет посты', () async {
      final p2pStorage = InMemoryCloudStorage();
      final p2pAdapter = FakeAdapter(p2pStorage, id: CloudProviderId.p2p);
      final p2pRegistry = CloudProviderRegistry([p2pAdapter]);
      final p2pConnections = CloudConnectionService(p2pRegistry, InMemoryKeyValueStore());

      final p2pSessions = VaultSessionFactory(
        connections: p2pConnections,
        deviceName: () => 'TestDevice',
      );

      final p2pKey = VaultKey(
        secret: List<int>.filled(32, 9),
        provider: CloudProviderId.p2p,
        label: 'Прямая доска',
      );

      final repo = await p2pSessions.open(p2pKey);
      final post = await repo.sendText('Привет через P2P!');
      expect(post.text, 'Привет через P2P!');

      final fetched = await repo.fetchPosts();
      expect(fetched.length, 1);
      expect(fetched.first.text, 'Привет через P2P!');
    });
  });
}
