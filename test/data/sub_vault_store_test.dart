import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/vault_key_derivation.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_codec.dart';
import 'package:transmitter/data/sub_vault_store.dart';

void main() {
  test(
    'Независимые устройства находят обе одновременно созданные поддоски',
    () async {
      final cloud = InMemoryCloudStorage();
      const derivation = VaultKeyDerivation();
      const codec = VaultKeyCodec();
      final parent = VaultKey.generate(
        provider: CloudProviderId.dropbox,
        label: 'Работа',
        accountId: 'account',
        accountEmail: 'owner@example.test',
      );

      Future<SubVaultStore> open(VaultKey key) async {
        final secrets = await derivation.derive(key.secret);
        return SubVaultStore(
          storage: cloud,
          parent: key,
          vaultId: secrets.vaultId,
          cipher: AesGcmCipher(secrets.encryptionKey),
          derivation: derivation,
        );
      }

      final firstDevice = await open(parent);
      final secondDevice = await open(codec.decode(codec.encode(parent)));
      expect(await firstDevice.list(), isEmpty);

      final children = await Future.wait([
        firstDevice.create('Проект А'),
        secondDevice.create('Проект Б'),
      ]);
      expect(await secondDevice.list(), children);
      expect(children.first.accountId, parent.accountId);
      expect(children.first.accountEmail, parent.accountEmail);
      expect(children.first.secret, isNot(children.last.secret));
      expect(children.first.secret, isNot(parent.secret));

      final childStore = await open(children.first);
      final grandchild = await childStore.create('Документы');
      final importedChild = codec.decode(codec.encode(children.first));
      expect(await (await open(importedChild)).list(), [grandchild]);
      expect(await (await open(children.last)).list(), isEmpty);
      expect(await firstDevice.list(), children);
    },
  );

  test('Редактирование, удаление поддосок и устойчивость к повреждённым файлам', () async {
    final cloud = InMemoryCloudStorage();
    const derivation = VaultKeyDerivation();
    final parent = VaultKey.generate(
      provider: CloudProviderId.dropbox,
      label: 'Базовая',
    );
    final secrets = await derivation.derive(parent.secret);
    final store = SubVaultStore(
      storage: cloud,
      parent: parent,
      vaultId: secrets.vaultId,
      cipher: AesGcmCipher(secrets.encryptionKey),
      derivation: derivation,
    );

    final child = await store.create('Старое название');
    expect((await store.list()).single.label, 'Старое название');

    // Обновление названия и лимита размера файла
    final updated = child.copyWith(
      label: 'Новое название',
      maxFileSize: 50 * 1024 * 1024,
    );
    await store.update(updated);

    final reloaded = (await store.list()).single;
    expect(reloaded.label, 'Новое название');
    expect(reloaded.maxFileSize, 50 * 1024 * 1024);

    // Добавляем повреждённый файл в облако: список не ломается, повреждённый пропускается
    final brokenFileName = 'sub-vault-v1-${secrets.vaultId}-broken.bin';
    cloud.files[brokenFileName] = Uint8List.fromList([1, 2, 3, 4, 5]);
    final listWithBroken = await store.list();
    expect(listWithBroken.length, 1);
    expect(listWithBroken.single.label, 'Новое название');

    // Удаление поддоски
    await store.delete(updated);
    expect(await store.list(), isEmpty);
  });
}
