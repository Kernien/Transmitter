import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/app_lock_controller.dart';
import 'package:transmitter/app/vault_session_factory.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/vault/vault_key_store.dart';
import 'package:transmitter/features/app_lock/app_lock_gate.dart';
import 'package:transmitter/features/app_lock/app_lock_settings_screen.dart';
import 'package:transmitter/features/vaults/vaults_controller.dart';
import 'package:transmitter/l10n/app_localizations.dart';

class _FakeBiometrics implements BiometricAuthenticator {
  bool available = false;
  bool result = false;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<bool> authenticate({required String reason}) async => result;
}

void main() {
  test('принимает только ПИН-код из четырёх цифр', () async {
    final store = InMemoryKeyValueStore();
    final fourDigit = AppLockController(store, iterations: 2);
    await fourDigit.load();
    await fourDigit.setPin('1942');

    final locked = AppLockController(store, iterations: 2);
    await locked.load();
    expect(await locked.verifyPin('1942'), isTrue);
    await expectLater(locked.setPin('194'), throwsArgumentError);
    await expectLater(locked.setPin('19425'), throwsArgumentError);
    await expectLater(locked.setPin('194256'), throwsArgumentError);
  });

  test(
    'ПИН сохраняется как проверочное значение и переживает перезапуск',
    () async {
      final store = InMemoryKeyValueStore();
      final first = AppLockController(store, iterations: 5);
      await first.load();
      await first.setPin('1942');

      final saved = await store.read('app_lock_pin4');
      expect(saved, isNot(contains('1942')));

      final reloaded = AppLockController(store, iterations: 5);
      await reloaded.load();
      expect(reloaded.isLocked, isTrue);
      expect(await reloaded.verifyPin('1943'), isFalse);
      expect(reloaded.isLocked, isTrue);
      expect(await reloaded.verifyPin('1942'), isTrue);
      expect(reloaded.isLocked, isFalse);
    },
  );

  test(
    'пять неверных попыток дают минутную задержку, сохранённую на диске',
    () async {
      final store = InMemoryKeyValueStore();
      var now = DateTime.utc(2026, 10, 31);
      DateTime clock() => now;
      final first = AppLockController(store, clock: clock, iterations: 2);
      await first.load();
      await first.setPin('1942');
      final locked = AppLockController(store, clock: clock, iterations: 2);
      await locked.load();

      for (var i = 0; i < 5; i++) {
        expect(await locked.verifyPin('0000'), isFalse);
      }
      expect(locked.lockoutSecondsRemaining, greaterThan(0));
      expect(await locked.verifyPin('1942'), isFalse);

      final reloaded = AppLockController(store, clock: clock, iterations: 2);
      await reloaded.load();
      expect(reloaded.lockoutSecondsRemaining, greaterThan(0));
      now = now.add(const Duration(minutes: 1, seconds: 1));
      expect(await reloaded.verifyPin('1942'), isTrue);
    },
  );

  test('биометрия разблокирует только при включённой настройке', () async {
    final store = InMemoryKeyValueStore();
    final biometrics = _FakeBiometrics()..available = true;
    final first = AppLockController(
      store,
      biometrics: biometrics,
      iterations: 2,
    );
    await first.load();
    await first.setPin('1942', useBiometrics: true);

    final locked = AppLockController(
      store,
      biometrics: biometrics..result = true,
      iterations: 2,
    );
    await locked.load();
    expect(await locked.unlockWithBiometrics(reason: 'Unlock'), isTrue);
    expect(locked.isLocked, isFalse);
  });

  test('блокировка включается после пяти минут в фоне', () async {
    final store = InMemoryKeyValueStore();
    var now = DateTime.utc(2026, 10, 31);
    DateTime clock() => now;
    final first = AppLockController(store, clock: clock, iterations: 2);
    await first.load();
    await first.setPin('1942');
    final controller = AppLockController(store, clock: clock, iterations: 2);
    await controller.load();
    await controller.verifyPin('1942');

    controller.onBackground();
    now = now.add(const Duration(minutes: 4, seconds: 59));
    controller.onForeground();
    expect(controller.isLocked, isFalse);

    controller.onBackground();
    now = now.add(AppLockController.backgroundTimeout);
    controller.onForeground();
    expect(controller.isLocked, isTrue);
  });

  test(
    'повреждённую запись нельзя принять за отключённую блокировку',
    () async {
      final store = InMemoryKeyValueStore()..values['app_lock_pin4'] = 'broken';
      final controller = AppLockController(store, iterations: 2);
      await controller.load();
      expect(controller.isEnabled, isTrue);
      expect(controller.isLocked, isTrue);
      expect(controller.canRecover, isTrue);
    },
  );

  test(
    'автозапрос биометрии не повторяется после отмены и снова доступен при блокировке',
    () async {
      final store = InMemoryKeyValueStore();
      final biometrics = _FakeBiometrics()..available = true;
      var now = DateTime.utc(2026, 10, 31);
      DateTime clock() => now;
      final setup = AppLockController(
        store,
        biometrics: biometrics,
        clock: clock,
        iterations: 2,
      );
      await setup.load();
      await setup.setPin('1942', useBiometrics: true);

      final locked = AppLockController(
        store,
        biometrics: biometrics,
        clock: clock,
        iterations: 2,
      );
      await locked.load();
      expect(locked.claimAutomaticBiometricAttempt(), isTrue);
      expect(await locked.unlockWithBiometrics(reason: 'Unlock'), isFalse);
      expect(locked.claimAutomaticBiometricAttempt(), isFalse);

      expect(await locked.verifyPin('1942'), isTrue);
      locked.onBackground();
      now = now.add(AppLockController.backgroundTimeout);
      locked.onForeground();
      expect(locked.isLocked, isTrue);
      expect(locked.claimAutomaticBiometricAttempt(), isTrue);
    },
  );

  testWidgets(
    'после неверного ПИН-кода поле ввода очищается на экране блокировки и в настройках',
    (tester) async {
      final store = InMemoryKeyValueStore();
      final controller = AppLockController(store, iterations: 2);
      await controller.load();
      await controller.setPin('1942');

      final locked = AppLockController(store, iterations: 2);
      await locked.load();
      final connections = CloudConnectionService(
        CloudProviderRegistry(const []),
        store,
      );
      final sessions = VaultSessionFactory(
        connections: connections,
        deviceName: () => 'Test',
      );
      final vaults = VaultsController(VaultKeyStore(store), settings: sessions);
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: locked,
          child: MaterialApp(
            navigatorKey: navKey,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => AppLockGate(
              controller: locked,
              vaults: vaults,
              sessions: sessions,
              navigatorKey: navKey,
              child: child!,
            ),
            home: const AppLockSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Неверный ПИН на экране блокировки -> поле должно очиститься.
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Разблокировать'));
      await tester.pumpAndSettle();
      expect(find.text('Неверный ПИН-код'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      // Разблокируем верным ПИН-кодом.
      await tester.enterText(find.byType(TextField), '1942');
      await tester.tap(find.text('Разблокировать'));
      await tester.pumpAndSettle();
      expect(locked.isLocked, isFalse);

      // Нажимаем «Изменить ПИН-код» и вводим неверный текущий ПИН -> поле очищается.
      await tester.tap(find.text('Изменить ПИН-код'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Неверный ПИН-код'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('под экраном блокировки фокус и ввод недоступны ленте', (
    tester,
  ) async {
    final store = InMemoryKeyValueStore();
    final setup = AppLockController(store, iterations: 2);
    await setup.load();
    await setup.setPin('1942');
    final locked = AppLockController(store, iterations: 2);
    await locked.load();
    final sessions = VaultSessionFactory(
      connections: CloudConnectionService(CloudProviderRegistry(const []), store),
      deviceName: () => 'Test',
    );
    final vaults = VaultsController(VaultKeyStore(store), settings: sessions);
    final navKey = GlobalKey<NavigatorState>();
    final feedField = FocusNode();
    addTearDown(feedField.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppLockGate(
          controller: locked,
          vaults: vaults,
          sessions: sessions,
          navigatorKey: navKey,
          child: child!,
        ),
        home: Scaffold(
          body: TextField(
            key: const Key('feed-field'),
            focusNode: feedField,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(locked.isLocked, isTrue);
    expect(feedField.hasFocus, isFalse);

    // Нажатие Tab не отдаёт фокус ленте под экраном блокировки.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(feedField.hasFocus, isFalse);

    // После разблокировки лента снова принимает фокус.
    await tester.enterText(find.byType(TextField).last, '1942');
    await tester.tap(find.text('Разблокировать'));
    await tester.pumpAndSettle();
    expect(locked.isLocked, isFalse);
    feedField.requestFocus();
    await tester.pump();
    expect(feedField.hasFocus, isTrue);
  });
}
