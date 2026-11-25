import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/vault_session_factory.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/external_opener.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/files/media_picker.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/share/outgoing_share.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/data/post_repository.dart';
import 'package:transmitter/features/feed/feed_screen.dart';
import 'package:transmitter/features/feed/widgets/compose_bar.dart';
import 'package:transmitter/features/vaults/manage_tags_dialog.dart';
import 'package:transmitter/features/vaults/vaults_controller.dart';
import 'package:transmitter/l10n/app_localizations.dart';

import '../support/fake_file_transfer_service.dart';

class _MultiSessionFactory implements VaultSessionFactory {
  _MultiSessionFactory(this.repos);

  final Map<String, PostRepository> repos;

  @override
  Future<PostRepository> open(VaultKey key) async => repos[key.label]!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('VaultsController: теги переживают перезапуск и сохраняются в VaultKeyStore', () async {
    final store = InMemoryKeyValueStore();
    final keyStore = VaultKeyStore(store);

    final c1 = VaultsController(keyStore);
    await c1.load();
    c1.registerTags(['бухгалтерия', 'отчётность']);

    expect(c1.allTags, ['бухгалтерия', 'отчётность']);

    // Симуляция перезапуска приложения
    final c2 = VaultsController(keyStore);
    await c2.load();
    expect(c2.allTags, ['бухгалтерия', 'отчётность']);
  });

  testWidgets(
    'теги одной доски автоматически доступны на другой доске (в диалоге тегов и подсказках ComposeBar)',
    (tester) async {
      final store = InMemoryKeyValueStore();
      final keyStore = VaultKeyStore(store);
      final vaultsController = VaultsController(keyStore);
      await vaultsController.load();

      final cloudA = InMemoryCloudStorage();
      final repoA = EncryptedCloudPostRepository(
        storage: cloudA,
        vaultId: 'vault_a',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'Device',
      );

      final cloudB = InMemoryCloudStorage();
      final repoB = EncryptedCloudPostRepository(
        storage: cloudB,
        vaultId: 'vault_b',
        cipher: AesGcmCipher(List<int>.filled(32, 2)),
        deviceName: 'Device',
      );

      final keyA = await vaultsController.create(
        provider: CloudProviderId.dropbox,
        label: 'Доска А',
      );
      final keyB = await vaultsController.create(
        provider: CloudProviderId.dropbox,
        label: 'Доска Б',
      );

      final sessionFactory = _MultiSessionFactory({
        'Доска А': repoA,
        'Доска Б': repoB,
      });

      // 1. Открываем Доску А и отправляем пост с тегом #клиенты
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VaultsController>.value(value: vaultsController),
            Provider<VaultSessionFactory>.value(value: sessionFactory),
            Provider<FileTransferService>(create: (_) => FakeFileTransferService()),
            Provider<MediaPicker>(create: (_) => const NoMediaPicker()),
            Provider<ExternalOpener>(create: (_) => const NoExternalOpener()),
            Provider<ShareSender>(create: (_) => const DisabledShareSender()),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeedScreen.vault(keyA),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Вводим текст поста с тегом #клиенты на Доске А
      await tester.enterText(find.byType(TextField), 'Важный контакт #клиенты');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Убеждаемся, что тег попал в пул пользователя
      expect(vaultsController.allTags.contains('клиенты'), isTrue);

      // 2. Теперь открываем Доску Б
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VaultsController>.value(value: vaultsController),
            Provider<VaultSessionFactory>.value(value: sessionFactory),
            Provider<FileTransferService>(create: (_) => FakeFileTransferService()),
            Provider<MediaPicker>(create: (_) => const NoMediaPicker()),
            Provider<ExternalOpener>(create: (_) => const NoExternalOpener()),
            Provider<ShareSender>(create: (_) => const DisabledShareSender()),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeedScreen.vault(keyB),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Проверяем подсказки тегов в ComposeBar на Доске Б при вводе '#'
      await tester.enterText(find.byType(TextField), 'Сделка #кл');
      await tester.pumpAndSettle();

      // Появился ActionChip подсказки '#клиенты', созданный на Доске А!
      expect(find.widgetWithText(ActionChip, '#клиенты'), findsOneWidget);

      // Кликаем по подсказке
      await tester.tap(find.widgetWithText(ActionChip, '#клиенты'));
      await tester.pumpAndSettle();

      // Тег подставился в строку ввода
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Сделка #клиенты ');

      // 3. Проверяем доступность в ManageTagsDialog на Доске Б
      final BuildContext currentContext = tester.element(find.byType(ComposeBar));
      List<String>? dialogResult;

      ManageTagsDialog.show(
        currentContext,
        initialTags: [],
        availableTags: [],
      ).then((res) => dialogResult = res);

      await tester.pumpAndSettle();

      // В блоке существующих тегов диалога виден тег '#клиенты', созданный на Доске А!
      expect(
        find.descendant(
          of: find.byType(ManageTagsDialog),
          matching: find.text('#клиенты'),
        ),
        findsOneWidget,
      );

      // Нажимаем Сохранить
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(dialogResult, isNull);
    },
  );
}
