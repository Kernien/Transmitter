import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/data/post_repository.dart';
import 'package:transmitter/domain/post.dart';

void main() {
  const vaultId = 'vault1';
  final key = List<int>.generate(32, (i) => 100 + i);

  late InMemoryCloudStorage cloud;
  late int tick;

  EncryptedCloudPostRepository device(String name, {List<int>? withKey}) =>
      EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: vaultId,
        cipher: AesGcmCipher(withKey ?? key),
        deviceName: name,
        // Каждый пост получает на секунду большее время, порядок предсказуем.
        clock: () => DateTime.utc(2026, 1, 1).add(Duration(seconds: tick++)),
      );

  setUp(() {
    cloud = InMemoryCloudStorage();
    tick = 0;
  });

  test('пост с одного устройства виден на другом', () async {
    final phone = device('Android');
    final pc = device('Windows');

    await phone.sendText('Привет с телефона');
    final posts = await pc.fetchPosts();

    expect(posts, hasLength(1));
    expect(posts.single.text, 'Привет с телефона');
    expect(posts.single.senderDevice, 'Android');
    expect(posts.single.kind, PostKind.text);
  });

  test('посты возвращаются в хронологическом порядке', () async {
    final a = device('A');
    final b = device('B');
    await a.sendText('1');
    await b.sendText('2');
    await a.sendText('3');
    expect((await device('C').fetchPosts()).map((p) => p.text), [
      '1',
      '2',
      '3',
    ]);
  });

  test('ссылка определяется автоматически', () async {
    final post = await device('A').sendText('  https://example.com/page?x=1  ');
    expect(post.kind, PostKind.link);
    expect(post.text, 'https://example.com/page?x=1');
    expect(
      (await device('A').sendText('см. https://example.com')).kind,
      PostKind.text,
    );
  });

  test('в облаке нет открытого текста', () async {
    await device('A').sendText('совершенно секретно');
    for (final bytes in cloud.files.values) {
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('секретно')),
      );
    }
  });

  test('пост с чужим ключом пропускается, остальные читаются', () async {
    await device('A').sendText('мой');
    await device('X', withKey: List<int>.filled(32, 9)).sendText('чужой');
    final posts = await device('B').fetchPosts();
    expect(posts.map((p) => p.text), ['мой']);
  });

  test('удаление на одном устройстве видно на другом', () async {
    final a = device('A');
    final b = device('B');
    final post = await a.sendText('удалить меня');
    await a.sendText('оставить');
    expect(await b.fetchPosts(), hasLength(2));

    await a.deletePost(post);
    expect((await b.fetchPosts()).map((p) => p.text), ['оставить']);
  });

  test('файл передаётся и расшифровывается', () async {
    final bytes = Uint8List.fromList(List<int>.generate(5000, (i) => i % 256));
    final sent = await device('A')
        .sendFile(fileName: 'photo.jpg', bytes: bytes, mimeType: 'image/jpeg');
    expect(sent.kind, PostKind.file);

    final receiver = device('B');
    final post = (await receiver.fetchPosts()).single;
    expect(post.attachment!.fileName, 'photo.jpg');
    expect(post.attachment!.size, 5000);
    expect(await receiver.downloadAttachment(post.attachment!), bytes);
  });

  test('удаление поста с файлом удаляет и файл', () async {
    final a = device('A');
    final post = await a.sendFile(fileName: 'a.txt', bytes: Uint8List(10));
    expect(cloud.files.keys.where((k) => k.contains('/files/')), hasLength(1));
    await a.deletePost(post);
    expect(cloud.files, isEmpty);
  });

  test('файл больше 25 МБ отклоняется', () {
    final big = Uint8List(VaultKey.defaultMaxFileSize + 1);
    expect(
      () => device('A').sendFile(fileName: 'big.bin', bytes: big),
      throwsA(isA<FileTooLargeException>()),
    );
  });

  test(
    'лимит базы берётся из ключа: 10 МБ пропускает 10 МБ, но не больше',
    () async {
      final small = EncryptedCloudPostRepository(
        storage: cloud,
        vaultId: vaultId,
        cipher: AesGcmCipher(key),
        deviceName: 'A',
        maxFileSize: 10 * 1024 * 1024,
      );
      expect(small.maxFileSize, 10 * 1024 * 1024);
      await small.sendFile(
        fileName: 'ok.bin',
        bytes: Uint8List(10 * 1024 * 1024),
      );
      expect(
        () => small.sendFile(
          fileName: 'big.bin',
          bytes: Uint8List(10 * 1024 * 1024 + 1),
        ),
        throwsA(
          isA<FileTooLargeException>().having(
            (e) => e.maxSize,
            'лимит',
            10 * 1024 * 1024,
          ),
        ),
      );
    },
  );

  test('пустая база возвращает пустой список', () async {
    expect(await device('A').fetchPosts(), isEmpty);
  });

  test('пустое сообщение не отправляется', () {
    expect(() => device('A').sendText('   '), throwsArgumentError);
  });
}
