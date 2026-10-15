import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/board_signature.dart';
import 'package:transmitter/core/crypto/cipher.dart';
import 'package:transmitter/data/board_manifest_codec.dart';
import 'package:transmitter/domain/board_snapshot.dart';
import 'package:transmitter/domain/post.dart';

void main() {
  final cipher = AesGcmCipher(List<int>.filled(32, 5));
  final codec = BoardManifestCodec(cipher);
  late BoardSigner owner;

  setUp(() async {
    owner = await BoardSigner.fromSeed(List<int>.filled(32, 1));
  });

  final snapshot = BoardSnapshot(
    label: 'Рецепты',
    updatedAt: DateTime.utc(2026, 10, 15, 12),
    posts: [
      Post(
        id: 'p1',
        kind: PostKind.link,
        createdAt: DateTime.utc(2026, 10, 1),
        senderDevice: 'Телефон',
        text: 'https://example.com/pie',
        note: PostNote(
          postId: 'p1',
          text: 'лучший пирог',
          editedAt: DateTime.utc(2026, 10, 2),
          editorDevice: 'Ноутбук',
        ),
      ),
      Post(
        id: 'p2',
        kind: PostKind.file,
        createdAt: DateTime.utc(2026, 10, 3),
        senderDevice: 'Телефон',
        attachment: const Attachment(
          id: 'f1',
          fileName: 'фото.jpg',
          size: 1000,
          mimeType: 'image/jpeg',
        ),
      ),
    ],
    fileLocators: const {'f1': 'locator-f1'},
  );

  test('опись читается владельцем подписанной, с комментариями', () async {
    final bytes = await codec.encode(snapshot, owner);
    final read = await codec.decode(bytes, BoardVerifier(owner.publicKey));

    expect(read.label, 'Рецепты');
    expect(read.updatedAt, snapshot.updatedAt);
    expect(read.posts.map((p) => p.id), ['p1', 'p2']);
    expect(read.posts.first.note!.text, 'лучший пирог');
    expect(read.posts.first.note!.editorDevice, 'Ноутбук');
    expect(read.posts.last.note, isNull);
    expect(read.posts.last.attachment!.fileName, 'фото.jpg');
    expect(read.fileLocators, {'f1': 'locator-f1'});
  });

  test('изменённый байт — подпись не сходится', () async {
    final bytes = await codec.encode(snapshot, owner);
    bytes[bytes.length - 1] ^= 1;
    expect(
      codec.decode(bytes, BoardVerifier(owner.publicKey)),
      throwsA(isA<BoardSignatureException>()),
    );
  });

  test('опись, подписанная не владельцем, отклоняется', () async {
    final stranger = await BoardSigner.fromSeed(List<int>.filled(32, 2));
    final bytes = await codec.encode(snapshot, stranger);
    expect(
      codec.decode(bytes, BoardVerifier(owner.publicKey)),
      throwsA(isA<BoardSignatureException>()),
    );
  });

  test('без ключа расшифровки содержимое не прочитать', () async {
    final bytes = await codec.encode(snapshot, owner);
    final wrongKey = BoardManifestCodec(AesGcmCipher(List<int>.filled(32, 6)));
    expect(
      wrongKey.decode(bytes, BoardVerifier(owner.publicKey)),
      throwsA(isA<DecryptionException>()),
    );
  });

  test('обрезанный файл — ошибка подписи, а не сбой', () {
    expect(
      codec.decode(
        Uint8List.fromList([1, 2, 3]),
        BoardVerifier(owner.publicKey),
      ),
      throwsA(isA<BoardSignatureException>()),
    );
  });
}
