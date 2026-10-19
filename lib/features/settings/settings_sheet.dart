import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/cache_settings.dart';
import '../../app/l10n.dart';
import '../../app/language_controller.dart';
import '../../app/theme_controller.dart';
import 'language_dialog.dart';
import 'storage_dialog.dart';
import 'theme_dialog.dart';

/// «Настройки»: оформление, язык, место на устройстве.
Future<void> showSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
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
    return SafeArea(
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
              subtitle: Text(l.storageLimitValue(l.fileSize(cache.limitBytes))),
              onTap: () => showStorageDialog(context),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
