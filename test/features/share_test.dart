import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/share/android_incoming_share_source.dart';
import 'package:transmitter/core/share/incoming_share.dart';
import 'package:transmitter/core/share/outgoing_share.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/domain/post.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/share_target/share_target_controller.dart';

import '../support/fake_file_transfer_service.dart';

class FakeShareSender implements ShareSender {
  String? text;
  List<OutgoingFile>? files;

  @override
  bool get isAvailable => true;

  @override
  Future<void> share({
    String? text,
    List<OutgoingFile> files = const [],
  }) async {
    this.text = text;
    this.files = files;
  }
}

void main() {
  late InMemoryCloudStorage cloud;

  EncryptedCloudPostRepository repo(String device) =>
      EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 8)),
        deviceName: device,
      );

  setUp(() => cloud = InMemoryCloudStorage());

  group('разбор данных от Android', () {
    test('текст, заголовок, файлы, слишком большой файл', () {
      final content = AndroidIncomingShareSource.parse({
        'text': 'https://example.com',
        'subject': 'Пример',
        'files': [
          {
            'name': 'a.jpg',
            'size': 3,
            'bytes': Uint8List.fromList([1, 2, 3]),
            'mimeType': 'image/jpeg',
          },
          {'name': 'big.mp4', 'size': 99999999, 'bytes': null},
        ],
      });
      expect(content.text, 'https://example.com');
      expect(content.subject, 'Пример');
      expect(content.files.first.bytes, [1, 2, 3]);
      expect(content.files.first.mimeType, 'image/jpeg');
      expect(content.files.last.isTooLarge, isTrue);
    });

    test('пустые данные', () {
      expect(AndroidIncomingShareSource.parse({}).isEmpty, isTrue);
    });
  });

  group('ShareTargetController', () {
    final dropbox = VaultKey.generate(
      provider: CloudProviderId.dropbox,
      label: 'Dropbox',
    );
    final gdrive = VaultKey.generate(
      provider: CloudProviderId.googleDrive,
      label: 'Drive',
    );

    ShareTargetController controller(SharedContent content) =>
        ShareTargetController(
          content: content,
          vaults: [gdrive, dropbox],
          isUsable: (k) => k.provider == CloudProviderId.dropbox,
          openVault: (_) async => repo('Android'),
        );

    test(
      'по умолчанию выбрана первая доступная база, недоступную выбрать нельзя',
      () {
        final c = controller(const SharedContent(text: 'x'));
        expect(c.selected, dropbox);
        c.select(gdrive);
        expect(c.selected, dropbox);
      },
    );

    test('ссылка уходит отдельным постом-ссылкой', () async {
      final c = controller(
        const SharedContent(
          text: ' https://example.com/a ',
          subject: 'Заголовок',
        ),
      );
      expect(c.totalCount, 1);
      expect(await c.send(), isTrue);

      final posts = await repo('Windows').fetchPosts();
      expect(posts.single.kind, PostKind.link);
      expect(posts.single.text, 'https://example.com/a');
      expect(posts.single.senderDevice, 'Android');
    });

    test(
      'файлы уходят, текст становится подписью к первому, большие пропускаются',
      () async {
        final c = controller(
          SharedContent(
            text: 'фото с отпуска',
            files: [
              SharedFile(
                name: '1.jpg',
                size: 2,
                bytes: Uint8List.fromList([1, 1]),
              ),
              const SharedFile(name: 'video.mp4', size: 90 << 20),
              SharedFile(
                name: '2.jpg',
                size: 2,
                bytes: Uint8List.fromList([2, 2]),
              ),
            ],
          ),
        );
        expect(c.totalCount, 2);
        expect(c.skippedFiles.single.name, 'video.mp4');
        expect(await c.send(), isTrue);
        expect(c.sentCount, 2);

        final posts = await repo('Windows').fetchPosts();
        expect(posts.map((p) => p.attachment!.fileName), ['1.jpg', '2.jpg']);
        expect(posts.first.text, 'фото с отпуска');
        expect(posts.last.text, '');
      },
    );

    test('только слишком большие файлы — отправлять нечего', () {
      final c = controller(
        const SharedContent(
          files: [SharedFile(name: 'big', size: 1 << 30)],
        ),
      );
      expect(c.canSend, isFalse);
    });

    test('без доступных баз отправить нельзя', () {
      final c = ShareTargetController(
        content: const SharedContent(text: 'x'),
        vaults: [gdrive],
        isUsable: (_) => false,
        openVault: (_) async => repo('A'),
      );
      expect(c.selected, isNull);
      expect(c.canSend, isFalse);
    });
  });

  group('Поделиться из ленты', () {
    test(
      'выбранные посты: тексты одним сообщением, файлы вложениями',
      () async {
        final share = FakeShareSender();
        final files = FakeFileTransferService();
        final feed = FeedController(
          repo('Windows'),
          files: files,
          share: share,
          pollInterval: const Duration(hours: 1),
        );
        await feed.sendText('первое');
        files.nextPick = PickedFile(
          name: 'doc.pdf',
          bytes: Uint8List.fromList([5, 5]),
        );
        await feed.attachFile(caption: 'подпись');
        await feed.sendText('https://example.com');
        feed.selectAll();

        expect(feed.canShare, isTrue);
        expect(await feed.shareSelected(), isTrue);
        expect(share.text, 'первое\n\nподпись\n\nhttps://example.com');
        expect(share.files!.single.name, 'doc.pdf');
        expect(share.files!.single.bytes, [5, 5]);
        expect(feed.isSelecting, isFalse);
        feed.dispose();
      },
    );

    test('без системного меню «Поделиться» действие недоступно', () {
      final feed = FeedController(
        repo('Windows'),
        files: FakeFileTransferService(),
        pollInterval: const Duration(hours: 1),
      );
      expect(feed.canShare, isFalse);
      feed.dispose();
    });
  });
}
