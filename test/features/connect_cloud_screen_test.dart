import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/features/cloud_connect/connect_cloud_screen.dart';
import 'package:transmitter/l10n/app_localizations.dart';

/// Облако со входом по паролю и кодом 2FA «123456».
class _PasswordAdapter implements PasswordCloudAdapter {
  final attempts = <(String, String, String?)>[];

  @override
  CloudProviderId get id => CloudProviderId.mega;

  @override
  bool get isConfigured => true;

  @override
  Future<String> signIn() => throw UnsupportedError('password only');

  @override
  Future<String> signInWithPassword({
    required String email,
    required String password,
    String? secondFactorCode,
  }) async {
    attempts.add((email, password, secondFactorCode));
    if (secondFactorCode != '123456') {
      throw const SecondFactorRequiredException();
    }
    return 'session';
  }

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) => InMemoryCloudStorage();
}

void main() {
  testWidgets('MEGA: почта и пароль, затем код 2FA', (tester) async {
    final adapter = _PasswordAdapter();
    final service = CloudConnectionService(
      CloudProviderRegistry([adapter]),
      InMemoryKeyValueStore(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ConnectCloudScreen(provider: CloudProviderId.mega),
        ),
      ),
    );

    expect(find.textContaining('Пароль не сохраняется'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Код двухфакторной аутентификации'),
      findsNothing,
    );

    await tester.enterText(find.widgetWithText(TextField, 'Почта'), 'me@x.org');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), 'secret');
    await tester.tap(find.text('Войти в MEGA'));
    await tester.pumpAndSettle();

    expect(
      find.text('Введите код из приложения-аутентификатора'),
      findsOneWidget,
    );
    final codeField = find.widgetWithText(
      TextField,
      'Код двухфакторной аутентификации',
    );
    expect(codeField, findsOneWidget);

    await tester.enterText(codeField, '123456');
    await tester.tap(find.text('Войти в MEGA'));
    await tester.pumpAndSettle();

    expect(adapter.attempts, [
      ('me@x.org', 'secret', null),
      ('me@x.org', 'secret', '123456'),
    ]);
    expect(service.isConnected(CloudProviderId.mega), isTrue);
  });
}
