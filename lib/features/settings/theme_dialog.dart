import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/theme_controller.dart';

/// Название пресета оформления на языке интерфейса.
String themeName(AppLocalizations l, AppTheme theme) => switch (theme) {
  AppTheme.system => l.themeSystem,
  AppTheme.light => l.themeLight,
  AppTheme.dark => l.themeDark,
  AppTheme.ocean => l.themeOcean,
  AppTheme.forest => l.themeForest,
  AppTheme.sunset => l.themeSunset,
  AppTheme.night => l.themeNight,
};

/// Выбор оформления: как в системе или один из пресетов (с образцом цвета).
Future<void> showThemeDialog(BuildContext context) {
  final controller = context.read<ThemeController>();
  return showDialog<void>(
    context: context,
    builder: (context) => ChangeNotifierProvider.value(
      value: controller,
      child: const _ThemeDialog(),
    ),
  );
}

class _ThemeDialog extends StatelessWidget {
  const _ThemeDialog();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = context.watch<ThemeController>();
    final platform = MediaQuery.platformBrightnessOf(context);
    return AlertDialog(
      title: Text(l.theme),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SingleChildScrollView(
        child: RadioGroup<AppTheme>(
          groupValue: controller.theme,
          onChanged: (theme) {
            if (theme != null) controller.select(theme);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final theme in AppTheme.values)
                RadioListTile<AppTheme>(
                  value: theme,
                  title: Text(themeName(l, theme)),
                  secondary: _Swatch(theme.data(platform)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.closeAction),
        ),
      ],
    );
  }
}

/// Образец: фон пресета и его основной цвет.
class _Swatch extends StatelessWidget {
  const _Swatch(this.theme);

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: CircleAvatar(radius: 9, backgroundColor: scheme.primary),
    );
  }
}
