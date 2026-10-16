import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/persistence/blob_cache.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/domain/post.dart';
import 'package:transmitter/features/feed/attachment_previews.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/widgets/post_tile.dart';
import 'package:transmitter/l10n/app_localizations.dart';

import '../support/fake_file_transfer_service.dart';

/// Настоящая картинка 1×1 (PNG).
final png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Облако, которое считает скачивания.
class CountingCloud extends InMemoryCloudStorage {
  int downloads = 0;

  @override
  Future<Uint8List> download(String path) {
    downloads++;
    return super.download(path);
  }
}

void main() {
  group('что считается фото', () {
    Attachment file(String name, [String? mime]) =>
        Attachment(id: 'a', fileName: name, size: 1, mimeType: mime);

    test('по типу и по расширению', () {
      expect(file('x', 'image/jpeg').isImage, isTrue);
      expect(file('IMG_1.HEIC').isImage, isTrue);
      expect(file('cat.png').isImage, isTrue);
      expect(file('logo.svg', 'image/svg+xml').isImage, isFalse);
      expect(file('отчёт.pdf', 'application/pdf').isImage, isFalse);
      expect(file('README').isImage, isFalse);
    });
  });

  group('AttachmentPreviews', () {
    const a = Attachment(id: 'a', fileName: 'a.png', size: 4);
    const b = Attachment(id: 'b', fileName: 'b.png', size: 4);

    test('одновременные запросы — одна загрузка', () async {
      var loads = 0;
      final previews = AttachmentPreviews((_) async {
        loads++;
        return Uint8List(4);
      });
      await Future.wait([previews.load(a), previews.load(a)]);
      await previews.load(a);
      expect(loads, 1);
      expect(previews.peek(a), isNotNull);
    });

    test('память ограничена: старое вытесняется', () async {
      final previews = AttachmentPreviews(
        (_) async => Uint8List(6),
        maxBytes: 10,
      );
      await previews.load(a);
      await previews.load(b);
      expect(previews.peek(a), isNull);
      expect(previews.peek(b), isNotNull);
    });

    test('ошибка загрузки не запоминается', () async {
      var fail = true;
      final previews = AttachmentPreviews((_) async {
        if (fail) throw StateError('нет сети');
        return Uint8List(1);
      });
      await expectLater(previews.load(a), throwsStateError);
      fail = false;
      expect(await previews.load(a), hasLength(1));
    });
  });

  group('кеш вложений на устройстве', () {
    late CountingCloud cloud;
    late MemoryBlobCache disk;

    EncryptedCloudPostRepository repo() => EncryptedCloudPostRepository(
      storage: cloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 2)),
      deviceName: 'A',
      blobs: disk,
    );

    setUp(() {
      cloud = CountingCloud();
      disk = MemoryBlobCache();
    });

    test('своё фото и повторный показ — без загрузки', () async {
      final post = await repo().sendFile(fileName: 'a.png', bytes: png);
      expect(await repo().downloadAttachment(post.attachment!), png);
      expect(cloud.downloads, 0);
    });

    test('чужое фото качается один раз', () async {
      final post = await EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 2)),
        deviceName: 'B',
      ).sendFile(fileName: 'a.png', bytes: png);
      await repo().downloadAttachment(post.attachment!);
      await repo().downloadAttachment(post.attachment!);
      expect(cloud.downloads, 1);
    });

    test('большие файлы не кешируются', () async {
      final big = Uint8List(attachmentCacheLimit + 1);
      final r = EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 2)),
        deviceName: 'A',
        blobs: disk,
        maxFileSize: 100 * 1024 * 1024,
      );
      await r.sendFile(fileName: 'big.zip', bytes: big);
      expect(disk.entries.keys.where((k) => k.startsWith('att-')), isEmpty);
    });

    test('удалённая запись забирает фото из кеша', () async {
      final mine = repo();
      final post = await mine.sendFile(fileName: 'a.png', bytes: png);
      await mine.fetchPosts();
      expect(
        disk.entries.keys.where((k) => k.startsWith('att-')),
        hasLength(1),
      );

      // Удалили с другого устройства.
      await EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 2)),
        deviceName: 'B',
      ).deletePost(post);
      await mine.fetchPosts();
      expect(disk.entries.keys.where((k) => k.startsWith('att-')), isEmpty);
    });
  });

  group('превью в ленте', () {
    Future<FeedController> feedWith(
      WidgetTester tester,
      Uint8List bytes, {
      String name = 'cat.png',
    }) async {
      final feed = FeedController(
        EncryptedCloudPostRepository(
          storage: InMemoryCloudStorage(),
          vaultId: 'v',
          cipher: AesGcmCipher(List<int>.filled(32, 1)),
          deviceName: 'A',
          maxFileSize: 100 * 1024 * 1024,
        ),
        files: FakeFileTransferService()
          ..nextPick = PickedFile(name: name, bytes: bytes),
        pollInterval: const Duration(hours: 1),
      );
      await tester.runAsync(() => feed.attachFile());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: feed,
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PostTile(post: feed.posts.single),
              ),
            ),
          ),
        ),
      );
      return feed;
    }

    testWidgets('небольшое фото показывается сразу', (tester) async {
      final feed = await feedWith(tester, png);
      await tester.runAsync(
        () => feed.previews.load(feed.posts.single.attachment!),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      feed.dispose();
    });

    testWidgets('большое фото — только по кнопке', (tester) async {
      final big = Uint8List(attachmentPreviewAutoLimit + 1)..setAll(0, png);
      final feed = await feedWith(tester, big, name: 'huge.png');
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Показать фото'), findsOneWidget);
      feed.dispose();
    });
  });
}
