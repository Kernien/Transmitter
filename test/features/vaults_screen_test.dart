import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/cache_settings.dart';
import 'package:transmitter/app/app_lock_controller.dart';
import 'package:transmitter/app/language_controller.dart';
import 'package:transmitter/app/theme_controller.dart';
import 'package:transmitter/core/persistence/blob_cache.dart';
import 'package:transmitter/core/device/device_identity.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/errors/app_error.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';
import 'package:transmitter/data/vault_settings.dart';
import 'package:transmitter/features/vaults/vaults_controller.dart';
import 'package:transmitter/features/vaults/vaults_screen.dart';
import 'package:transmitter/l10n/app_localizations.dart';

import '../core/device_identity_test.dart' show FakeSuggester;

/// Облачные настройки баз в памяти; [fail] — облако недоступно.
class FakeSettings implements VaultSettingsRemote {
  final Map<String, VaultSettings> saved = {};
  bool fail = false;

  @override
  Future<VaultSettings?> loadSettings(VaultKey key) async => saved[key.label];

  @override
  Future<void> saveSettings(VaultKey key, VaultSettings settings) async {
    if (fail) throw const StorageAuthException(ErrorCode.cloudNotConnected);
    saved[key.label] = settings;
  }
}

Future<VaultsController> pumpScreen(
  WidgetTester tester,
  VaultSettingsRemote settings,
) async {
  final store = InMemoryKeyValueStore();
  final vaults = VaultsController(VaultKeyStore(store), settings: settings);
  await vaults.create(label: 'Работа', provider: CloudProviderId.dropbox);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              CloudConnectionService(CloudProviderRegistry(const []), store),
        ),
        ChangeNotifierProvider.value(value: vaults),
        ChangeNotifierProvider(
          create: (_) =>
              DeviceIdentity(store, FakeSuggester(() async => 'Тест')),
        ),
        ChangeNotifierProvider(
          create: (_) => CacheSettings(const NoBlobCache(), store),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VaultsScreen(),
      ),
    ),
  );
  return vaults;
}

Future<void> chooseFileSize(WidgetTester tester, String size) async {
  await tester.tap(find.byIcon(Icons.more_vert).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Размер файлов…'));
  await tester.pumpAndSettle();
  expect(find.text('Максимальный размер файла'), findsOneWidget);
  await tester.tap(find.text(size));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('«Размер файлов…»: новый лимит сохраняется', (tester) async {
    final settings = FakeSettings();
    final vaults = await pumpScreen(tester, settings);
    expect(find.textContaining('25 МБ'), findsNothing, reason: 'не подключено');

    await chooseFileSize(tester, '100 МБ');
    expect(vaults.vaults.single.maxFileSize, 100 * 1024 * 1024);
    expect(settings.saved['Работа']!.maxFileSize, 100 * 1024 * 1024);
  });

  testWidgets('«Размер файлов…» без облака — понятная ошибка', (tester) async {
    final settings = FakeSettings()..fail = true;
    final vaults = await pumpScreen(tester, settings);

    await chooseFileSize(tester, '100 МБ');
    expect(vaults.vaults.single.maxFileSize, VaultKey.defaultMaxFileSize);
    expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
  });

  testWidgets('имя устройства и облака доступны в настройках', (tester) async {
    final store = InMemoryKeyValueStore();
    final device = DeviceIdentity(store, FakeSuggester(() async => 'Тест'));
    await device.rename('Ноутбук');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                CloudConnectionService(CloudProviderRegistry(const []), store),
          ),
          ChangeNotifierProvider(
            create: (_) => VaultsController(VaultKeyStore(store)),
          ),
          ChangeNotifierProvider.value(value: device),
          ChangeNotifierProvider(create: (_) => LanguageController(store)),
          ChangeNotifierProvider(create: (_) => ThemeController(store)),
          ChangeNotifierProvider(create: (_) => AppLockController(store)),
          ChangeNotifierProvider(
            create: (_) => CacheSettings(const NoBlobCache(), store),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VaultsScreen(),
        ),
      ),
    );

    expect(find.byIcon(Icons.badge_outlined), findsNothing);
    expect(find.byIcon(Icons.cloud_outlined), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Ноутбук'), findsOneWidget);
    expect(find.text('Облака'), findsOneWidget);
    await tester.tap(find.text('Имя устройства'));
    await tester.pumpAndSettle();
    expect(find.text('Имя устройства'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'Ноутбук'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Облака'));
    await tester.pumpAndSettle();
    expect(find.text('Dropbox'), findsOneWidget);
  });

  testWidgets('база без шифрования отмечается в списке', (tester) async {
    final settings = FakeSettings();
    final vaults = await pumpScreen(tester, settings);
    await vaults.create(
      label: 'Фото архив',
      provider: CloudProviderId.dropbox,
      isEncrypted: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Фото архив'), findsOneWidget);
    expect(find.textContaining('без шифрования'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
  });

  testWidgets('закрепление базы: переключение в меню и значок булавки', (tester) async {
    final settings = FakeSettings();
    final vaults = await pumpScreen(tester, settings);

    // Изначально значка булавки нет.
    expect(find.byIcon(Icons.push_pin), findsNothing);

    // Открываем меню базы.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Закрепить'), findsOneWidget);

    // Закрепляем базу.
    await tester.tap(find.text('Закрепить'));
    await tester.pumpAndSettle();

    // Появился значок булавки.
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(vaults.isPinned(vaults.vaults.first), isTrue);

    // В меню теперь пункт «Открепить».
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Открепить'), findsOneWidget);

    // Открепляем.
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(vaults.isPinned(vaults.vaults.first), isFalse);
  });
}
