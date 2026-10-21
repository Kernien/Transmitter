import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/cache_settings.dart';
import 'package:transmitter/app/language_controller.dart';
import 'package:transmitter/app/theme_controller.dart';
import 'package:transmitter/core/persistence/blob_cache.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/features/settings/settings_sheet.dart';
import 'package:transmitter/l10n/app_localizations.dart';

void main() {
  test('выбор оформления сохраняется на устройстве', () async {
    final store = InMemoryKeyValueStore();
    final controller = ThemeController(store);
    await controller.load();
    expect(controller.theme, AppTheme.system);
    expect(controller.mode, ThemeMode.system);

    await controller.select(AppTheme.forest);
    final reloaded = ThemeController(store);
    await reloaded.load();
    expect(reloaded.theme, AppTheme.forest);
    expect(reloaded.mode, ThemeMode.dark);
  });

  test('пресеты: светлые, тёмные и чёрная «Ночь»', () {
    expect(AppTheme.light.data(Brightness.dark).brightness, Brightness.light);
    expect(AppTheme.dark.data(Brightness.light).brightness, Brightness.dark);
    expect(AppTheme.ocean.data(Brightness.dark).brightness, Brightness.light);
    expect(
      AppTheme.night.data(Brightness.light).colorScheme.surface,
      Colors.black,
    );
    // «Как в системе» — по настройке устройства.
    expect(AppTheme.system.data(Brightness.dark).brightness, Brightness.dark);
    // Пресеты различаются основным цветом.
    final primaries = {
      for (final t in AppTheme.values.where((t) => t != AppTheme.system))
        t.data(Brightness.light).colorScheme.primary,
    };
    expect(primaries.length, greaterThanOrEqualTo(5));
  });

  test('темы редакторов: родные фон и акцент, всегда тёмные', () {
    final dracula = AppTheme.dracula.data(Brightness.light).colorScheme;
    expect(dracula.brightness, Brightness.dark);
    expect(dracula.surface, const Color(0xFF282A36));
    expect(dracula.primary, const Color(0xFFBD93F9));
    expect(dracula.onSurface, const Color(0xFFF8F8F2));

    final palettes = [
      for (final t in AppTheme.values)
        if (t.palette != null) t,
    ];
    expect(palettes, hasLength(6));
    for (final t in palettes) {
      expect(t.brightness, Brightness.dark, reason: t.name);
      final scheme = t.data(Brightness.light).colorScheme;
      // Текст и кнопки читаются на фоне (контраст не меньше 4.5:1).
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
    }
    // Фоны у всех тем разные.
    expect({
      for (final t in palettes) t.data(Brightness.dark).colorScheme.surface,
    }, hasLength(6));
  });

  testWidgets('«Настройки» → «Оформление» → пресет', (tester) async {
    final store = InMemoryKeyValueStore();
    final theme = ThemeController(store);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider(create: (_) => LanguageController(store)),
          ChangeNotifierProvider(
            create: (_) => CacheSettings(const NoBlobCache(), store),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSettingsSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Оформление'), findsOneWidget);
    expect(find.text('Язык'), findsWidgets);
    // В вебе (кеша на диске нет) пункта «Место на устройстве» нет.
    expect(find.text('Место на устройстве'), findsNothing);

    await tester.tap(find.text('Оформление'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ночь (чёрная)'));
    await tester.pumpAndSettle();
    expect(theme.theme, AppTheme.night);
  });
}

/// Контраст двух цветов по WCAG.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
