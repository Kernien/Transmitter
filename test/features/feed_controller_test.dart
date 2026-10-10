import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';

void main() {
  late InMemoryCloudStorage cloud;

  FeedController controllerFor(String device) => FeedController(
        EncryptedCloudPostRepository(
          storage: cloud,
          vaultId: 'v',
          cipher: AesGcmCipher(List<int>.filled(32, 3)),
          deviceName: device,
        ),
        pollInterval: const Duration(hours: 1),
      );

  setUp(() => cloud = InMemoryCloudStorage());

  test('отправка добавляет пост сразу, без ожидания опроса', () async {
    final feed = controllerFor('A');
    expect(await feed.sendText('привет'), isTrue);
    expect(feed.posts.single.text, 'привет');
    expect(feed.isSending, isFalse);
    feed.dispose();
  });

  test('refresh подтягивает посты другого устройства', () async {
    final a = controllerFor('A');
    final b = controllerFor('B');
    await a.sendText('от A');
    await b.refresh();
    expect(b.posts.single.text, 'от A');
    expect(b.isInitialLoad, isFalse);
    a.dispose();
    b.dispose();
  });

  test('ошибка отправки показывается в error, а не роняет приложение', () async {
    final feed = controllerFor('A');
    expect(await feed.sendText('   '), isFalse);
    expect(feed.error, isNotNull);
    feed.dispose();
  });
}
