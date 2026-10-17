import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/vault/reader_key.dart';
import 'package:transmitter/core/vault/reader_key_codec.dart';
import 'package:transmitter/core/vault/reader_key_store.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_codec.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';
import 'package:transmitter/features/vaults/vaults_controller.dart';

void main() {
  late InMemoryKeyValueStore store;

  VaultsController controller() =>
      VaultsController(VaultKeyStore(store), readers: ReaderKeyStore(store));

  final readerKey = ReaderKey(
    provider: CloudProviderId.googleDrive,
    label: 'Рецепты',
    locator: 'file-id',
    encryptionKey: List<int>.filled(32, 1),
    ownerPublicKey: List<int>.filled(32, 2),
  );
  final ownerCode = const VaultKeyCodec().encode(
    VaultKey(
      secret: List<int>.filled(32, 3),
      provider: CloudProviderId.dropbox,
      label: 'Личное',
    ),
  );

  setUp(() => store = InMemoryKeyValueStore());

  test('ключ читателя попадает в доски, ключ базы — в базы', () async {
    final c = controller();
    await c.load();
    final board = await c.importAny(
      '  ${const ReaderKeyCodec().encode(readerKey)}\n',
    );
    final vault = await c.importAny(ownerCode);
    expect(board, isA<ReaderKey>());
    expect(vault, isA<VaultKey>());
    expect(c.boards, [readerKey]);
    expect(c.vaults.single.label, 'Личное');

    // Повторный импорт не дублирует.
    await c.importAny(const ReaderKeyCodec().encode(readerKey));
    expect(c.boards, hasLength(1));
  });

  test('доски сохраняются, переименовываются и удаляются', () async {
    final c = controller();
    await c.load();
    await c.importAny(const ReaderKeyCodec().encode(readerKey));
    await c.renameBoard(readerKey, '  Кулинария ');

    final reloaded = controller();
    await reloaded.load();
    expect(reloaded.boards.single.label, 'Кулинария');
    expect(
      const ReaderKeyCodec().decode(
        reloaded.exportBoardCode(reloaded.boards.single),
      ),
      readerKey.copyWith(label: 'Кулинария'),
    );

    await reloaded.removeBoard(readerKey);
    final empty = controller();
    await empty.load();
    expect(empty.boards, isEmpty);
  });

  test('название от владельца обновляется, своё — нет', () async {
    final c = controller();
    await c.load();
    await c.importAny(const ReaderKeyCodec().encode(readerKey));

    await c.applyOwnerLabel(readerKey, 'Рецепты бабушки');
    expect(c.boardLabel(readerKey), 'Рецепты бабушки');

    await c.renameBoard(readerKey, 'Моё');
    await c.applyOwnerLabel(readerKey, 'Ещё новее');
    expect(c.boardLabel(readerKey), 'Моё');

    // После перезапуска своё название по-прежнему главное.
    final reloaded = controller();
    await reloaded.load();
    await reloaded.applyOwnerLabel(readerKey, 'Ещё новее');
    expect(reloaded.boardLabel(readerKey), 'Моё');
  });

  test(
    'ключи читателя хранятся как в 0.7.0 — старые версии их прочтут',
    () async {
      final c = controller();
      await c.load();
      await c.importAny(const ReaderKeyCodec().encode(readerKey));
      await c.renameBoard(readerKey, 'Моё');
      final raw = await store.read('reader_keys');
      expect(raw, startsWith('['));
    },
  );
}
