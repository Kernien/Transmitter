import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/selection_exporter.dart';

import '../support/fake_file_transfer_service.dart';

void main() {
  late InMemoryCloudStorage cloud;
  late FakeFileTransferService files;
  late FeedController feed;
  var tick = 0;

  FeedController controllerFor(String device) => FeedController(
        EncryptedCloudPostRepository(
          storage: cloud,
          vaultId: 'v',
          cipher: AesGcmCipher(List<int>.filled(32, 5)),
          deviceName: device,
          clock: () => DateTime.utc(2026, 3, 1, 9).add(Duration(minutes: tick++)),
        ),
        files: files,
        pollInterval: const Duration(hours: 1),
        clock: () => DateTime(2026, 3, 1, 18, 30),
      );

  Future<void> sendFile(String name, List<int> bytes, {String caption = ''}) async {
    files.nextPick = PickedFile(name: name, bytes: Uint8List.fromList(bytes));
    await feed.attachFile(caption: caption);
  }

  setUp(() {
    cloud = InMemoryCloudStorage();
    files = FakeFileTransferService();
    tick = 0;
    feed = controllerFor('Windows');
  });

  tearDown(() => feed.dispose());

  test('выделение: переключение, выбрать все, снятие', () async {
    await feed.sendText('a');
    await feed.sendText('b');
    expect(feed.isSelecting, isFalse);

    feed.toggleSelection(feed.posts.first);
    expect(feed.isSelecting, isTrue);
    expect(feed.selectedCount, 1);

    feed.selectAll();
    expect(feed.selectedCount, 2);

    feed.toggleSelection(feed.posts.first);
    expect(feed.isSelected(feed.posts.first), isFalse);

    feed.clearSelection();
    expect(feed.isSelecting, isFalse);
  });

  test('удаление выбранного удаляет только выбранное', () async {
    await feed.sendText('оставить');
    await feed.sendText('удалить 1');
    await sendFile('x.bin', [1, 2]);
    for (final post in feed.posts.skip(1)) {
      feed.toggleSelection(post);
    }

    expect(await feed.deleteSelected(), 2);
    expect(feed.posts.map((p) => p.text), ['оставить']);
    expect(feed.isSelecting, isFalse);
    expect(cloud.files, hasLength(1));
  });

  test('один выбранный файл сохраняется как есть', () async {
    await sendFile('photo.jpg', [9, 9, 9]);
    feed.toggleSelection(feed.posts.single);

    expect(await feed.saveSelected(), isTrue);
    expect(files.saved.single.$1, 'photo.jpg');
    expect(files.saved.single.$2, [9, 9, 9]);
    expect(feed.isSelecting, isFalse);
  });

  test('несколько постов — zip с файлами и сообщения.txt', () async {
    await feed.sendText('привет');
    await sendFile('a.txt', [1], caption: 'подпись');
    await sendFile('a.txt', [2]);
    await feed.sendText('https://example.com');
    feed.selectAll();

    expect(await feed.saveSelected(), isTrue);
    final (name, bytes) = files.saved.single;
    expect(name, 'transmitter_2026-03-01_18-30.zip');

    final archive = ZipDecoder().decodeBytes(bytes);
    final byName = {for (final f in archive) f.name: f.content};
    expect(byName.keys, containsAll(['a.txt', 'a (2).txt', SelectionExporter.messagesFileName]));
    expect(byName['a.txt'], [1]);
    expect(byName['a (2).txt'], [2]);

    final raw = byName[SelectionExporter.messagesFileName]!;
    // BOM для Блокнота (utf8.decode его отбрасывает, поэтому проверяем байты).
    expect(raw.take(3), [0xEF, 0xBB, 0xBF]);
    final text = utf8.decode(raw);
    expect(text.indexOf('привет'), lessThan(text.indexOf('подпись')));
    expect(text, contains('файл a.txt'));
    expect(text, contains('https://example.com'));
    expect(text, contains('Windows'));
  });

  test('отмена сохранения оставляет выделение', () async {
    await feed.sendText('a');
    feed.selectAll();
    files.saveAccepted = false;
    expect(await feed.saveSelected(), isFalse);
    expect(feed.isSelecting, isTrue);
  });

  test('пост, удалённый на другом устройстве, пропадает из выделения', () async {
    await feed.sendText('a');
    await feed.sendText('b');
    feed.selectAll();

    final other = controllerFor('Android');
    await other.refresh();
    await other.delete(other.posts.first);
    other.dispose();

    await feed.refresh();
    expect(feed.selectedCount, 1);
  });
}
