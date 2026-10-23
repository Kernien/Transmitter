import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/cache_settings.dart';
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

    await chooseFileSize(tester, '50 МБ');
    expect(vaults.vaults.single.maxFileSize, 50 * 1024 * 1024);
    expect(settings.saved['Работа']!.maxFileSize, 50 * 1024 * 1024);
  });

  testWidgets('«Размер файлов…» без облака — понятная ошибка', (tester) async {
    final settings = FakeSettings()..fail = true;
    final vaults = await pumpScreen(tester, settings);

    await chooseFileSize(tester, '50 МБ');
    expect(vaults.vaults.single.maxFileSize, VaultKey.defaultMaxFileSize);
    expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
  });

  testWidgets('на главном экране есть кнопка имени устройства', (tester) async {
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

    final button = find.byIcon(Icons.badge_outlined);
    expect(button, findsOneWidget);
    expect(find.byTooltip('Имя устройства: Ноутбук'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Имя устройства'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Ноутбук'), findsOneWidget);
  });
}
