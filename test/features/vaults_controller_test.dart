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

  test('сброс ключей очищает доски только на устройстве', () async {
    final c = controller();
    await c.load();
    await c.importAny(ownerCode);
    await c.importAny(const ReaderKeyCodec().encode(readerKey));

    await c.clearLocalKeys();

    expect(c.vaults, isEmpty);
    expect(c.boards, isEmpty);
    expect(await store.read('vault_keys'), '[]');
    expect(await store.read('reader_keys'), '[]');
    expect(await store.read('reader_custom_labels'), '[]');
  });

  test('закрепление доски: только одна, смена открепляет старую, переживает перезапуск', () async {
    final c = controller();
    await c.load();
    final vault1 = await c.create(label: 'База 1', provider: CloudProviderId.dropbox);
    final vault2 = await c.create(label: 'База 2', provider: CloudProviderId.googleDrive);
    await c.importAny(const ReaderKeyCodec().encode(readerKey));

    expect(c.pinnedVault, isNull);
    expect(c.pinnedBoard, isNull);
    expect(c.isPinned(vault1), isFalse);

    // Закрепляем первую базу.
    await c.togglePinned(vault1);
    expect(c.isPinned(vault1), isTrue);
    expect(c.isPinned(vault2), isFalse);
    expect(c.pinnedVault?.sameVaultAs(vault1), isTrue);

    // Закрепление второй базы автоматически открепляет первую.
    await c.togglePinned(vault2);
    expect(c.isPinned(vault1), isFalse);
    expect(c.isPinned(vault2), isTrue);
    expect(c.pinnedVault?.sameVaultAs(vault2), isTrue);

    // Закрепление публичной доски открепляет базу.
    await c.togglePinned(readerKey);
    expect(c.isPinned(vault2), isFalse);
    expect(c.isPinned(readerKey), isTrue);
    expect(c.pinnedBoard?.sameBoardAs(readerKey), isTrue);
    expect(c.pinnedVault, isNull);

    // Перезапуск сохраняет закрепление.
    final reloaded = controller();
    await reloaded.load();
    expect(reloaded.isPinned(readerKey), isTrue);

    // Повторное переключение открепляет.
    await reloaded.togglePinned(readerKey);
    expect(reloaded.isPinned(readerKey), isFalse);
    expect(reloaded.pinnedKey, isNull);

    // Удаление закреплённой доски сбрасывает закрепление.
    await reloaded.togglePinned(vault1);
    expect(reloaded.isPinned(vault1), isTrue);
    await reloaded.remove(vault1);
    expect(reloaded.pinnedKey, isNull);
  });
}
