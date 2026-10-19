import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/device/device_identity.dart';
import '../core/files/external_opener.dart';
import '../core/files/file_transfer_service.dart';
import '../core/files/media_picker.dart';
import '../core/share/incoming_share.dart';
import '../core/share/outgoing_share.dart';
import '../core/storage/cloud_connection_service.dart';
import '../features/device/device_name_prompt.dart';
import '../features/share_target/incoming_share_listener.dart';
import '../features/vaults/vaults_controller.dart';
import '../features/vaults/vaults_screen.dart';
import '../l10n/app_localizations.dart';
import 'cache_settings.dart';
import 'language_controller.dart';
import 'theme_controller.dart';
import 'vault_session_factory.dart';

class TransmitterApp extends StatelessWidget {
  const TransmitterApp({
    super.key,
    required this.connections,
    required this.vaults,
    required this.device,
    required this.language,
    required this.cacheSettings,
    required this.theme,
    required this.sessions,
    required this.files,
    this.media = const NoMediaPicker(),
    this.opener = const NoExternalOpener(),
    required this.incomingShares,
    required this.shareSender,
  });

  final CloudConnectionService connections;
  final VaultsController vaults;
  final DeviceIdentity device;
  final LanguageController language;
  final CacheSettings cacheSettings;
  final ThemeController theme;
  final VaultSessionFactory sessions;
  final FileTransferService files;
  final MediaPicker media;
  final ExternalOpener opener;
  final IncomingShareSource incomingShares;
  final ShareSender shareSender;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connections),
        ChangeNotifierProvider.value(value: vaults),
        ChangeNotifierProvider.value(value: device),
        ChangeNotifierProvider.value(value: language),
        ChangeNotifierProvider.value(value: cacheSettings),
        ChangeNotifierProvider.value(value: theme),
        Provider.value(value: sessions),
        Provider<FileTransferService>.value(value: files),
        Provider<MediaPicker>.value(value: media),
        Provider<ExternalOpener>.value(value: opener),
        Provider<IncomingShareSource>.value(value: incomingShares),
        Provider<ShareSender>.value(value: shareSender),
      ],
      child: Consumer2<LanguageController, ThemeController>(
        builder: (context, language, theme, _) => MaterialApp(
          title: 'Transmitter',
          // Язык: выбранный в приложении или (null) как в системе — русский
          // или английский, для остальных языков английский. Тексты —
          // lib/l10n/*.arb.
          locale: language.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          // Оформление: как в системе или выбранный пресет.
          theme: theme.light,
          darkTheme: theme.dark,
          themeMode: theme.mode,
          home: const IncomingShareListener(
            child: DeviceNamePrompt(child: VaultsScreen()),
          ),
        ),
      ),
    );
  }
}
