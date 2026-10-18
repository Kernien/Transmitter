import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/cache_settings.dart';
import 'package:transmitter/core/persistence/blob_cache.dart';
import 'package:transmitter/core/device/device_identity.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';
import 'package:transmitter/features/vaults/vaults_controller.dart';
import 'package:transmitter/features/vaults/vaults_screen.dart';
import 'package:transmitter/l10n/app_localizations.dart';

import '../core/device_identity_test.dart' show FakeSuggester;

void main() {
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
