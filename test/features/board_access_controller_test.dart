import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/board_signature.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/vault/reader_key_codec.dart';
import 'package:transmitter/data/board_publisher.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/features/vaults/board_access_controller.dart';

import '../support/sharing_cloud.dart';

void main() {
  final key = List<int>.filled(32, 4);
  late SharingCloud cloud;
  late BoardSigner signer;

  setUp(() async {
    cloud = SharingCloud();
    signer = await BoardSigner.fromSeed(List<int>.filled(32, 8));
  });

  BoardAccessController controller({
    Future<BoardPublisher?> Function()? publisher,
  }) => BoardAccessController(
    label: 'Рецепты',
    publisher:
        publisher ??
        () async => BoardPublisher(
          storage: cloud,
          sharing: cloud,
          vaultId: 'v',
          cipher: AesGcmCipher(key),
          encryptionKey: key,
          signer: signer,
          provider: CloudProviderId.dropbox,
          loadPosts: EncryptedCloudPostRepository(
            storage: cloud,
            vaultId: 'v',
            cipher: AesGcmCipher(key),
            deviceName: 'A',
          ).fetchPosts,
        ),
  );

  test('открыть доступ, увидеть ключ, закрыть', () async {
    final c = controller();
    await c.load();
    expect(c.status, BoardAccessStatus.closed);
    expect(c.readerCode, isNull);

    expect(await c.openAccess(), isTrue);
    expect(c.status, BoardAccessStatus.open);
    final reader = const ReaderKeyCodec().decode(c.readerCode!);
    expect(reader.label, 'Рецепты');

    // Окно открыли снова — ключ тот же.
    final again = controller();
    await again.load();
    expect(again.readerCode, c.readerCode);

    expect(await c.closeAccess(), isTrue);
    expect(c.status, BoardAccessStatus.closed);
    expect(c.readerCode, isNull);
  });

  test('облако без публичных ссылок', () async {
    final c = controller(publisher: () async => null);
    await c.load();
    expect(c.status, BoardAccessStatus.unsupported);
  });

  test('облако не подключено — ошибка и повтор', () async {
    var attempts = 0;
    final c = controller(
      publisher: () async {
        attempts++;
        throw const StorageAuthException();
      },
    );
    await c.load();
    expect(c.status, BoardAccessStatus.failed);
    expect(c.error, isA<StorageAuthException>());
    await c.load();
    expect(attempts, 2);
  });
}
