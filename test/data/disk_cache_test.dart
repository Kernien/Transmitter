import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/board_signature.dart';
import 'package:transmitter/core/persistence/blob_cache.dart';
import 'package:transmitter/core/persistence/file_blob_cache.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/board_publisher.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/data/public_board_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';

import '../support/fake_file_transfer_service.dart';
import '../support/sharing_cloud.dart';

/// Облако, которое считает скачивания и может «пропасть» (нет сети).
class FlakyCloud extends InMemoryCloudStorage {
  int downloads = 0;
  bool offline = false;

  void _check() {
    if (offline) throw StorageException.request('Dropbox', 'offline');
  }

  @override
  Future<List<RemoteFile>> listFiles(String folder) {
    _check();
    return super.listFiles(folder);
  }

  @override
  Future<Uint8List> download(String path) {
    _check();
    downloads++;
    return super.download(path);
  }
}

void main() {
  final key = List<int>.filled(32, 7);
  late FlakyCloud cloud;
  late MemoryBlobCache disk;

  setUp(() {
    cloud = FlakyCloud();
    disk = MemoryBlobCache();
  });

  /// Новый экземпляр — как после перезапуска приложения.
  EncryptedCloudPostRepository launch(String device, {BlobCache? blobs}) =>
      EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: 'v',
        cipher: AesGcmCipher(key),
        deviceName: device,
        blobs: blobs ?? disk.scope('dropbox-v'),
      );

  group('записи на устройстве', () {
    test('после перезапуска лента видна без загрузок и без сети', () async {
      final phone = launch('Телефон');
      final post = await phone.sendText('первая');
      await phone.setNote(post, 'пояснение');
      await launch('Ноутбук', blobs: MemoryBlobCache()).sendText('вторая');
      await phone.fetchPosts();

      cloud.offline = true;
      final restarted = launch('Телефон');
      expect(restarted.cachedPosts, isNull);
      await restarted.warmUp();
      final posts = restarted.cachedPosts!;
      expect(posts.map((p) => p.text), ['первая', 'вторая']);
      expect(posts.first.note!.text, 'пояснение');

      cloud.offline = false;
      final downloads = cloud.downloads;
      await restarted.fetchPosts();
      expect(cloud.downloads, downloads, reason: 'всё уже на устройстве');
    });

    test('удалённое на другом устройстве убирается и из кеша', () async {
      final phone = launch('Телефон');
      final post = await phone.sendText('временная');
      await phone.fetchPosts();
      expect(disk.entries.keys.where((k) => k.endsWith('.post')), hasLength(1));

      await launch('Ноутбук', blobs: MemoryBlobCache()).deletePost(post);
      await phone.fetchPosts();
      expect(disk.entries.keys.where((k) => k.endsWith('.post')), isEmpty);

      final restarted = launch('Телефон');
      await restarted.warmUp();
      expect(restarted.cachedPosts, isEmpty);
    });

    test('испорченный файл в кеше скачивается заново', () async {
      final phone = launch('Телефон');
      await phone.sendText('целая');
      await phone.fetchPosts();
      final cached = disk.entries.keys.firstWhere((k) => k.endsWith('.post'));
      disk.entries[cached] = Uint8List.fromList([1, 2, 3]);

      final restarted = launch('Телефон');
      await restarted.warmUp();
      expect(restarted.cachedPosts, isEmpty);
      final posts = await restarted.fetchPosts();
      expect(posts.single.text, 'целая');
      expect(cloud.downloads, 1);
    });

    test('лента без сети показывает сохранённое и ошибку', () async {
      final phone = launch('Телефон');
      await phone.sendText('сохранённая');
      await phone.fetchPosts();

      cloud.offline = true;
      final feed = FeedController(
        launch('Телефон'),
        files: FakeFileTransferService(),
        pollInterval: const Duration(hours: 1),
      )..start();
      await pumpEventQueue();
      expect(feed.isInitialLoad, isFalse);
      expect(feed.posts.single.text, 'сохранённая');
      expect(feed.error, isA<StorageException>());
      feed.dispose();
    });
  });

  test(
    'доска у читателя открывается из кеша; закрыта — копия удаляется',
    () async {
      final sharing = SharingCloud();
      final signer = await BoardSigner.fromSeed(List<int>.filled(32, 5));
      final owner = EncryptedCloudPostRepository(
        storage: sharing,
        vaultId: 'v',
        cipher: AesGcmCipher(key),
        deviceName: 'Владелец',
      );
      await owner.sendText('на доске');
      final publisher = BoardPublisher(
        storage: sharing,
        sharing: sharing,
        vaultId: 'v',
        cipher: AesGcmCipher(key),
        encryptionKey: key,
        signer: signer,
        provider: CloudProviderId.dropbox,
        loadPosts: owner.fetchPosts,
      );
      final readerKey = await publisher.open(label: 'Доска');

      PublicBoardRepository reader() => PublicBoardRepository(
        reader: SharingCloudReader(sharing),
        key: readerKey,
        blobs: disk.scope('board'),
      );
      await reader().fetchPosts();

      final restarted = reader();
      await restarted.warmUp();
      expect(restarted.cachedPosts!.single.text, 'на доске');

      await publisher.close();
      await expectLater(
        restarted.fetchPosts(),
        throwsA(isA<BoardClosedException>()),
      );
      expect(disk.entries.keys.where((k) => k.startsWith('board/')), isEmpty);
    },
  );

  test('кеш в папке на диске', () async {
    final dir = await Directory.systemTemp.createTemp('transmitter_cache');
    addTearDown(() => dir.delete(recursive: true));
    final cache = FileBlobCache(dir).scope('dropbox-v');

    expect(await cache.read('a.post'), isNull);
    await cache.write('a.post', [1, 2, 3]);
    expect(await cache.read('a.post'), [1, 2, 3]);
    expect(await FileBlobCache(dir).scope('dropbox-v').read('a.post'), [
      1,
      2,
      3,
    ], reason: 'переживает перезапуск');
    expect(await FileBlobCache(dir).scope('other').read('a.post'), isNull);
    await cache.delete('a.post');
    await cache.delete('a.post');
    expect(await cache.read('a.post'), isNull);
  });
}
