import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/errors/app_error.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';

import '../support/fake_file_transfer_service.dart';

void main() {
  late InMemoryCloudStorage cloud;
  late FakeFileTransferService files;

  FeedController controllerFor(String device) => FeedController(
    EncryptedCloudPostRepository(
      storage: cloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 3)),
      deviceName: device,
    ),
    files: files,
    pollInterval: const Duration(hours: 1),
  );

  setUp(() {
    cloud = InMemoryCloudStorage();
    files = FakeFileTransferService();
  });

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

  test(
    'ошибка отправки показывается в error, а не роняет приложение',
    () async {
      final feed = controllerFor('A');
      expect(await feed.sendText('   '), isFalse);
      expect(feed.error, isNotNull);
      feed.dispose();
    },
  );

  test('очистка ленты удаляет всё на всех устройствах', () async {
    final a = controllerFor('A');
    await a.sendText('1');
    files.nextPick = PickedFile(name: 'f.bin', bytes: Uint8List(10));
    await a.attachFile();
    expect(cloud.files, hasLength(3)); // два поста и файл

    expect(await a.clearAll(), 2);
    expect(a.posts, isEmpty);
    expect(cloud.files, isEmpty);

    final b = controllerFor('B');
    await b.refresh();
    expect(b.posts, isEmpty);
    a.dispose();
    b.dispose();
  });

  group('файлы', () {
    final bytes = Uint8List.fromList(List<int>.generate(1000, (i) => i % 251));

    test(
      'прикреплённый файл уходит с подписью и сохраняется на другом устройстве',
      () async {
        final sender = controllerFor('A');
        files.nextPick = PickedFile(
          name: 'отчёт.pdf',
          bytes: bytes,
          mimeType: 'application/pdf',
        );
        expect(await sender.attachFile(caption: 'посмотри'), isTrue);
        expect(files.lastMaxSize, VaultKey.defaultMaxFileSize);

        final receiver = controllerFor('B');
        await receiver.refresh();
        final post = receiver.posts.single;
        expect(post.attachment!.fileName, 'отчёт.pdf');
        expect(post.text, 'посмотри');

        expect(await receiver.saveAttachment(post), isTrue);
        expect(files.saved.single.$1, 'отчёт.pdf');
        expect(files.saved.single.$2, bytes);
        expect(receiver.isSaving(post), isFalse);
        sender.dispose();
        receiver.dispose();
      },
    );

    test(
      'отмена выбора файла ничего не отправляет и не показывает ошибку',
      () async {
        final feed = controllerFor('A');
        files.nextPick = null;
        expect(await feed.attachFile(), isFalse);
        expect(feed.posts, isEmpty);
        expect(feed.error, isNull);
        feed.dispose();
      },
    );

    test('слишком большой файл — понятная ошибка', () async {
      final feed = controllerFor('A');
      files.pickError = FileTooLargeException(
        30 << 20,
        VaultKey.defaultMaxFileSize,
      );
      expect(await feed.attachFile(), isFalse);
      expect(feed.error, isA<FileTooLargeException>());
      feed.dispose();
    });

    test('отмена сохранения возвращает false без ошибки', () async {
      final feed = controllerFor('A');
      files.nextPick = PickedFile(name: 'a.txt', bytes: bytes);
      await feed.attachFile();
      files.saveAccepted = false;
      expect(await feed.saveAttachment(feed.posts.single), isFalse);
      expect(feed.error, isNull);
      feed.dispose();
    });

    test('перетащенные файлы: нормальные уходят, слишком большой — ошибка с именем', () async {
      final feed = controllerFor('A');
      final sent = await feed.sendDroppedFiles([
        // На компьютере XFile берёт имя из пути, как у перетащенного файла.
        XFile.fromData(bytes, path: 'one.txt'),
        XFile.fromData(
          Uint8List(VaultKey.defaultMaxFileSize + 1),
          path: 'huge.iso',
        ),
        XFile.fromData(bytes, path: 'two.txt'),
      ]);
      expect(sent, 2);
      expect(feed.posts.map((p) => p.attachment!.fileName), [
        'one.txt',
        'two.txt',
      ]);
      expect(
        feed.error,
        isA<FileError>()
            .having((e) => e.fileName, 'файл', 'huge.iso')
            .having((e) => e.cause, 'причина', isA<FileTooLargeException>()),
      );
      feed.dispose();
    });

    test('файл, удалённый из облака, — понятная ошибка', () async {
      final feed = controllerFor('A');
      files.nextPick = PickedFile(name: 'a.txt', bytes: bytes);
      await feed.attachFile();
      cloud.files.removeWhere((path, _) => path.contains('/files/'));
      expect(await feed.saveAttachment(feed.posts.single), isFalse);
      expect(feed.error, isA<StorageNotFoundException>());
      feed.dispose();
    });
  });
}
