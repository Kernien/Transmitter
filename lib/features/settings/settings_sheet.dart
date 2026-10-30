import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/cache_settings.dart';
import '../../app/l10n.dart';
import '../../app/language_controller.dart';
import '../../app/theme_controller.dart';
import '../../core/device/device_identity.dart';
import '../cloud_connect/clouds_screen.dart';
import '../device/device_name_dialog.dart';
import 'language_dialog.dart';
import 'storage_dialog.dart';
import 'theme_dialog.dart';

/// «Настройки»: устройство, облака, оформление, язык и место на устройстве.
Future<void> showSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = context.watch<ThemeController>().theme;
    final language = context.watch<LanguageController>().language;
    final cache = context.watch<CacheSettings>();
    final device = context.watch<DeviceIdentity>();
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l.settings,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(l.deviceNameTitle),
              subtitle: Text(device.name),
              onTap: () => showDeviceNameDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(l.clouds),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CloudsScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l.theme),
              subtitle: Text(themeName(l, theme)),
              onTap: () => showThemeDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l.language),
              subtitle: Text(
                language == AppLanguage.system
                    ? l.languageSystem
                    : language.nativeName,
              ),
              onTap: () => showLanguageDialog(context),
            ),
            if (cache.isAvailable)
              ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text(l.storageTitle),
                subtitle: Text(
                  l.storageLimitValue(l.fileSize(cache.limitBytes)),
                ),
                onTap: () => showStorageDialog(context),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
