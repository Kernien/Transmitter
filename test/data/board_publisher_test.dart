import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/board_signature.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/vault/reader_key.dart';
import 'package:transmitter/data/board_manifest_codec.dart';
import 'package:transmitter/data/board_publisher.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/data/publishing_post_repository.dart';
import 'package:transmitter/domain/board_snapshot.dart';

import '../support/sharing_cloud.dart';

void main() {
  const vaultId = 'vault1';
  final encryptionKey = List<int>.generate(32, (i) => i + 1);
  late SharingCloud cloud;
  late BoardSigner signer;
  late int tick;

  DateTime clock() => DateTime.utc(2026, 1, 1).add(Duration(seconds: tick++));

  setUp(() async {
    cloud = SharingCloud();
    signer = await BoardSigner.fromSeed(List<int>.filled(32, 3));
    tick = 0;
  });

  EncryptedCloudPostRepository repository(String device) =>
      EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: vaultId,
        cipher: AesGcmCipher(encryptionKey),
        deviceName: device,
        clock: clock,
      );

  BoardPublisher publisher({Duration stateTtl = const Duration(minutes: 1)}) =>
      BoardPublisher(
        storage: cloud,
        sharing: cloud,
        vaultId: vaultId,
        cipher: AesGcmCipher(encryptionKey),
        encryptionKey: encryptionKey,
        signer: signer,
        provider: CloudProviderId.dropbox,
        loadPosts: repository('Опись').fetchPosts,
        clock: clock,
        stateTtl: stateTtl,
      );

  /// Как читатель: только ключ читателя и чтение по ссылкам.
  Future<BoardSnapshot> readAsReader(ReaderKey key) async {
    final bytes = await SharingCloudReader(cloud).download(key.locator);
    return BoardManifestCodec(AesGcmCipher(key.encryptionKey))
        .decode(bytes, BoardVerifier(key.ownerPublicKey));
  }

  test('пока доступ не открыт, в облако ничего не пишется', () async {
    final repo = PublishingPostRepository(repository('A'), publisher());
    await repo.sendText('личное');
    await repo.fetchPosts();
    await repo.idle;
    expect(cloud.files.keys.where((p) => p.contains('/board/')), isEmpty);
    expect(cloud.published, isEmpty);
    expect(await publisher().state(), isNull);
  });

  test('открыть доступ: читатель видит записи, комментарии и файлы', () async {
    final owner = PublishingPostRepository(repository('Телефон'), publisher());
    final link = await owner.sendText('https://example.com/pie');
    await owner.setNote(link, 'лучший пирог');
    final file = await owner.sendFile(
      fileName: 'фото.jpg',
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
    );

    final key = await publisher().open(label: 'Рецепты');
    expect(key.label, 'Рецепты');
    expect(key.ownerPublicKey, signer.publicKey);
    expect(key.encryptionKey, encryptionKey);

    await owner.fetchPosts();
    await owner.idle;

    final board = await readAsReader(key);
    expect(board.label, 'Рецепты');
    expect(board.posts.map((p) => p.text), ['https://example.com/pie', '']);
    expect(board.posts.first.note!.text, 'лучший пирог');

    // Файл читается по ссылке тем же ключом.
    final locator = board.fileLocators[file.attachment!.id]!;
    final encrypted = await SharingCloudReader(cloud).download(locator);
    expect(await AesGcmCipher(key.encryptionKey).decrypt(encrypted), [1, 2, 3]);
  });

  test('новые записи, правки и удаления попадают в опись', () async {
    final owner = PublishingPostRepository(repository('A'), publisher());
    final key = await publisher().open(label: 'Доска');
    final first = await owner.sendText('первая');
    await owner.idle;
    expect((await readAsReader(key)).posts.single.text, 'первая');

    await owner.setNote(first, 'пояснение');
    await owner.idle;
    expect((await readAsReader(key)).posts.single.note!.text, 'пояснение');

    await owner.deletePost(first);
    await owner.idle;
    expect((await readAsReader(key)).posts, isEmpty);
  });

  test('без изменений опись не переписывается', () async {
    final owner = PublishingPostRepository(repository('A'), publisher());
    await publisher().open(label: 'Доска');
    await owner.sendText('запись');
    await owner.idle;
    final uploads = cloud.uploads;
    final publishes = cloud.publishCalls;

    await owner.fetchPosts();
    await owner.idle;
    await owner.fetchPosts();
    await owner.idle;
    expect(cloud.uploads, uploads);
    expect(cloud.publishCalls, publishes);
  });

  test('два устройства владельца с разными названиями не спорят', () async {
    final phone = PublishingPostRepository(repository('Телефон'), publisher());
    final pc = PublishingPostRepository(repository('Ноутбук'), publisher());
    await publisher().open(label: 'Общая');
    await phone.sendText('запись');
    await phone.idle;
    await pc.fetchPosts();
    await pc.idle;

    final uploads = cloud.uploads;
    for (var i = 0; i < 3; i++) {
      await phone.fetchPosts();
      await phone.idle;
      await pc.fetchPosts();
      await pc.idle;
    }
    expect(cloud.uploads, uploads, reason: 'опись одинакова на обоих');
  });

  test('открытие убирает описи, оставшиеся от прерванных попыток', () async {
    await cloud.ensureFolder('$vaultId/board');
    await cloud.upload('$vaultId/board/old.board', Uint8List(3));
    final key = await publisher().open(label: 'Доска');
    final manifests = cloud.files.keys.where((p) => p.endsWith('.board'));
    expect(manifests, hasLength(1));
    expect(key.locator, 'pub:${manifests.single}');
  });

  test('переименование доски видно читателям', () async {
    final key = await publisher().open(label: 'Старое');
    expect(await publisher().rename('Новое'), isTrue);
    expect((await readAsReader(key)).label, 'Новое');
    // Ключ для новых читателей — тоже с новым названием.
    expect(
      publisher().readerKeyFor((await publisher().state())!).label,
      'Новое',
    );

    await publisher().close();
    expect(await publisher().rename('Третье'), isFalse);
  });

  test('повторное открытие с другого устройства даёт тот же ключ', () async {
    final first = await publisher().open(label: 'Доска');
    final second = await publisher().open(label: 'Другое название');
    expect(second, first);
  });

  test('закрыть доступ: старый ключ перестаёт работать', () async {
    final owner = PublishingPostRepository(repository('A'), publisher());
    await owner.sendFile(fileName: 'a.bin', bytes: Uint8List(4));
    final key = await publisher().open(label: 'Доска');
    await owner.fetchPosts();
    await owner.idle;
    expect(cloud.published, hasLength(2), reason: 'опись и файл');

    await publisher().close();
    expect(await publisher().state(), isNull);
    expect(cloud.published, isEmpty);
    expect(readAsReader(key), throwsA(isA<StorageNotFoundException>()));
    // Записи владельца на месте.
    expect(await owner.fetchPosts(), hasLength(1));

    // Новое открытие — новый ключ, старый не оживает.
    final reopened = await publisher().open(label: 'Доска');
    expect(reopened.locator, isNot(key.locator));
    expect(readAsReader(key), throwsA(isA<StorageNotFoundException>()));
  });

  test(
    'доступ закрыли с другого устройства — опись больше не пишется',
    () async {
      final owner = PublishingPostRepository(
        repository('A'),
        publisher(stateTtl: Duration.zero),
      );
      await publisher().open(label: 'Доска');
      await owner.sendText('1');
      await owner.idle;

      await publisher().close();
      await owner.sendText('2');
      await owner.idle;
      expect(cloud.files.keys.where((p) => p.contains('/board/')), isEmpty);
      expect(owner.backgroundError, isNull);
    },
  );

  test('ошибка обновления доски не ломает ленту', () async {
    final failing = _FailingSharingCloud();
    cloud = failing;
    final owner = PublishingPostRepository(repository('A'), publisher());
    await publisher().open(label: 'Доска');
    failing.fail = true;
    await owner.sendFile(fileName: 'a.bin', bytes: Uint8List(4));
    await owner.idle;
    expect(owner.backgroundError, isA<StorageException>());
    expect(await owner.fetchPosts(), hasLength(1));
  });
}

class _FailingSharingCloud extends SharingCloud {
  bool fail = false;

  @override
  Future<String> publish(String path) {
    if (fail) throw StorageException.request('Dropbox', '500');
    return super.publish(path);
  }
}
