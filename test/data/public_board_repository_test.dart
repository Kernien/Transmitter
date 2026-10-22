import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/board_signature.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/vault/reader_key.dart';
import 'package:transmitter/data/board_manifest_codec.dart';
import 'package:transmitter/data/board_publisher.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/data/public_board_repository.dart';
import 'package:transmitter/data/publishing_post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';

import '../support/fake_file_transfer_service.dart';
import '../support/sharing_cloud.dart';

/// Сквозной сценарий: владелец открывает доступ, читатель читает только
/// по ключу читателя и ссылкам.
void main() {
  const vaultId = 'vault1';
  final encryptionKey = List<int>.generate(32, (i) => 200 - i);
  late SharingCloud cloud;
  late BoardSigner signer;

  setUp(() async {
    cloud = SharingCloud();
    signer = await BoardSigner.fromSeed(List<int>.filled(32, 11));
  });

  EncryptedCloudPostRepository ownerRepository() =>
      EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: vaultId,
        cipher: AesGcmCipher(encryptionKey),
        deviceName: 'Телефон',
      );

  BoardPublisher publisher() => BoardPublisher(
    storage: cloud,
    sharing: cloud,
    vaultId: vaultId,
    cipher: AesGcmCipher(encryptionKey),
    encryptionKey: encryptionKey,
    signer: signer,
    provider: CloudProviderId.dropbox,
    loadPosts: ownerRepository().fetchPosts,
  );

  PublicBoardRepository reader(ReaderKey key) =>
      PublicBoardRepository(reader: SharingCloudReader(cloud), key: key);

  test('читатель видит записи с комментариями и скачивает файлы', () async {
    final owner = PublishingPostRepository(ownerRepository(), publisher());
    final link = await owner.sendText('https://example.com');
    await owner.setNote(link, 'интересно');
    final file = await owner.sendFile(
      fileName: 'отчёт.pdf',
      bytes: Uint8List.fromList([5, 6, 7]),
    );
    final key = await publisher().open(label: 'Доска');

    final board = reader(key);
    expect(board.isReadOnly, isTrue);
    final posts = await board.fetchPosts();
    expect(posts, hasLength(2));
    expect(posts.first.note!.text, 'интересно');
    expect(posts.last.attachment!.fileName, 'отчёт.pdf');
    expect(await board.downloadAttachment(file.attachment!), [5, 6, 7]);
  });

  test('изменить доску читатель не может', () async {
    final key = await publisher().open(label: 'Доска');
    final board = reader(key);
    expect(() => board.sendText('чужое'), throwsUnsupportedError);
    expect(
      () => board.sendFile(fileName: 'x', bytes: Uint8List(1)),
      throwsUnsupportedError,
    );
    final posts = await board.fetchPosts();
    expect(posts, isEmpty);
  });

  test('после закрытия доступа — понятная ошибка', () async {
    final key = await publisher().open(label: 'Доска');
    await publisher().close();
    expect(reader(key).fetchPosts(), throwsA(isA<BoardClosedException>()));
  });

  test('лента читателя после закрытия пустеет и сообщает об этом', () async {
    final owner = PublishingPostRepository(ownerRepository(), publisher());
    await owner.sendText('на доске');
    final key = await publisher().open(label: 'Доска');
    final feed = FeedController(
      reader(key),
      files: FakeFileTransferService(),
      pollInterval: const Duration(hours: 1),
    );
    await feed.refresh();
    expect(feed.posts.single.text, 'на доске');

    await publisher().close();
    await feed.refresh();
    expect(feed.posts, isEmpty);
    expect(feed.error, isA<BoardClosedException>());
    feed.dispose();
  });

  test('подменённую опись читатель отклоняет', () async {
    final key = await publisher().open(label: 'Доска');
    final manifest = cloud.files.keys.firstWhere((p) => p.endsWith('.board'));
    cloud.files[manifest]![cloud.files[manifest]!.length - 1] ^= 1;
    expect(reader(key).fetchPosts(), throwsA(isA<BoardSignatureException>()));
  });
}
