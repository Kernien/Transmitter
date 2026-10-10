import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/vault_session_factory.dart';
import 'core/auth/platform_auth_browser.dart';
import 'core/files/file_picker_transfer_service.dart';
import 'core/persistence/key_value_store.dart';
import 'core/share/android_incoming_share_source.dart';
import 'core/share/incoming_share.dart';
import 'core/share/outgoing_share.dart';
import 'core/storage/cloud_connection_service.dart';
import 'core/storage/cloud_provider_adapter.dart';
import 'core/storage/providers/dropbox/dropbox_adapter.dart';
import 'core/utils/device_name.dart';
import 'core/vault/vault_key_store.dart';
import 'data/post_repository.dart';
import 'features/vaults/vaults_controller.dart';

/// Точка сборки зависимостей. Конкретные реализации создаются только здесь,
/// остальной код получает их через интерфейсы.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStore = FlutterSecureKeyValueStore();
  final httpClient = http.Client();
  final authBrowser = createPlatformAuthBrowser();

  // Сюда добавляются адаптеры облаков по мере их реализации.
  final registry = CloudProviderRegistry([
    DropboxAdapter(
      appKey: AppConfig.dropboxAppKey,
      browser: authBrowser,
      client: httpClient,
    ),
  ]);

  final connections = CloudConnectionService(registry, secureStore);
  final vaults = VaultsController(const VaultKeyStore(secureStore));
  await Future.wait([connections.load(), vaults.load()]);

  runApp(
    TransmitterApp(
      connections: connections,
      vaults: vaults,
      sessions: VaultSessionFactory(
        connections: connections,
        deviceName: currentDeviceName(),
      ),
      files: const FilePickerTransferService(),
      incomingShares: isAndroid
          ? AndroidIncomingShareSource(maxFileSize: PostRepository.maxFileSize)
          : const NoIncomingShares(),
      // Системное меню «Поделиться» есть на телефонах; на компьютере и в вебе
      // те же задачи решают «Копировать» и «Сохранить».
      shareSender: SharePlusSender(isAvailable: isAndroid),
    ),
  );
}

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
