import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/external_opener.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';

import '../support/fake_file_transfer_service.dart';

class FakeOpener implements ExternalOpener {
  String? fileName;
  Uint8List? bytes;
  String? mimeType;
  bool noApp = false;

  @override
  bool get isAvailable => true;

  @override
  Future<void> open({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (noApp) throw const NoAppToOpenException();
    this.fileName = fileName;
    this.bytes = bytes;
    this.mimeType = mimeType;
  }

  @override
  Future<void> cleanUp() async {}
}

void main() {
  late FakeOpener opener;
  late FeedController feed;
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  setUp(() async {
    opener = FakeOpener();
    feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 5)),
        deviceName: 'A',
      ),
      files: FakeFileTransferService()
        ..nextPick = PickedFile(
          name: 'книга.pdf',
          bytes: bytes,
          mimeType: 'application/pdf',
        ),
      opener: opener,
      pollInterval: const Duration(hours: 1),
    );
    await feed.attachFile();
  });
  tearDown(() => feed.dispose());

  test('файл передаётся другому приложению расшифрованным', () async {
    expect(feed.canOpenExternally, isTrue);
    await feed.openExternally(feed.posts.single);
    expect(opener.fileName, 'книга.pdf');
    expect(opener.bytes, bytes);
    expect(opener.mimeType, 'application/pdf');
    expect(feed.error, isNull);
  });

  test('нечем открыть — понятная ошибка', () async {
    opener.noApp = true;
    await feed.openExternally(feed.posts.single);
    expect(feed.error, isA<NoAppToOpenException>());
  });

  test('без такой возможности (веб) пункта нет', () {
    final web = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 5)),
        deviceName: 'A',
      ),
      files: FakeFileTransferService(),
      pollInterval: const Duration(hours: 1),
    );
    expect(web.canOpenExternally, isFalse);
    web.dispose();
  });
}
