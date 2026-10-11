import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/language_controller.dart';
import 'app/vault_session_factory.dart';
import 'core/auth/auth_browser.dart';
import 'core/auth/platform_auth_browser.dart';
import 'core/device/device_identity.dart';
import 'core/device/platform_device_name_suggester.dart';
import 'core/files/file_picker_transfer_service.dart';
import 'core/persistence/key_value_store.dart';
import 'core/share/android_incoming_share_source.dart';
import 'core/share/incoming_share.dart';
import 'core/share/outgoing_share.dart';
import 'core/storage/cloud_connection_service.dart';
import 'core/storage/cloud_provider_adapter.dart';
import 'core/storage/providers/dropbox/dropbox_adapter.dart';
import 'core/storage/providers/google_drive/google_drive_adapter.dart';
import 'core/vault/vault_key.dart';
import 'core/vault/vault_key_store.dart';
import 'features/vaults/vaults_controller.dart';

/// Точка сборки зависимостей. Конкретные реализации создаются только здесь,
/// остальной код получает их через интерфейсы.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStore = FlutterSecureKeyValueStore();
  final httpClient = http.Client();

  // Язык интерфейса (системный или выбранный в приложении). Тексты вне
  // виджетов — страница входа в браузере, подсказки имени устройства,
  // диалог сохранения — берутся из него в момент показа.
  final language = LanguageController(secureStore);
  await language.load();
  AuthPageTexts authTexts() {
    final l = language.current;
    return AuthPageTexts(
      title: l.authPageTitle,
      closeHint: l.authPageClose,
      returnLabel: l.authPageReturn,
    );
  }

  final authBrowser = createPlatformAuthBrowser(texts: authTexts);

  // Сюда добавляются адаптеры облаков по мере их реализации.
  final registry = CloudProviderRegistry([
    DropboxAdapter(
      appKey: AppConfig.dropboxAppKey,
      browser: authBrowser,
      client: httpClient,
    ),
    GoogleDriveAdapter(
      clientId: kIsWeb
          ? AppConfig.googleWebClientId
          : AppConfig.googleDesktopClientId,
      clientSecret: kIsWeb ? '' : AppConfig.googleDesktopClientSecret,
      browserFlow: kIsWeb,
      browser: createLoopbackAuthBrowser(texts: authTexts),
      client: httpClient,
    ),
  ]);

  final connections = CloudConnectionService(registry, secureStore);
  final vaults = VaultsController(const VaultKeyStore(secureStore));
  final device = DeviceIdentity(
    secureStore,
    createPlatformDeviceNameSuggester(
      workProfileLabel: () => language.current.deviceWorkProfile,
      browserName: () => language.current.deviceBrowserName,
    ),
  );
  await Future.wait([connections.load(), vaults.load(), device.load()]);

  runApp(
    TransmitterApp(
      connections: connections,
      vaults: vaults,
      device: device,
      sessions: VaultSessionFactory(
        connections: connections,
        deviceName: () => device.name,
      ),
      language: language,
      files: FilePickerTransferService(
        saveDialogTitle: () => language.current.actionSaveFile,
      ),
      incomingShares: isAndroid
          ? AndroidIncomingShareSource(
              maxFileSize: VaultKey.absoluteMaxFileSize,
            )
          : const NoIncomingShares(),
      // Системное меню «Поделиться» есть на телефонах; на компьютере и в вебе
      // те же задачи решают «Копировать» и «Сохранить».
      shareSender: SharePlusSender(isAvailable: isAndroid),
    ),
  );
}

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
