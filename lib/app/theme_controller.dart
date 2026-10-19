import 'package:flutter/material.dart';

import '../core/persistence/key_value_store.dart';

/// Оформление приложения: как в системе или один из пресетов.
enum AppTheme {
  /// Светлая или тёмная — как в настройках устройства.
  system(Colors.indigo, null),
  light(Colors.indigo, Brightness.light),
  dark(Colors.indigo, Brightness.dark),
  ocean(Colors.teal, Brightness.light),
  forest(Colors.green, Brightness.dark),
  sunset(Colors.deepOrange, Brightness.light),

  /// Чёрный фон — бережёт батарею на OLED-экранах.
  night(Colors.deepPurple, Brightness.dark);

  const AppTheme(this.seed, this.brightness);

  /// Основной цвет, из которого строится палитра.
  final Color seed;

  /// `null` — как в системе.
  final Brightness? brightness;

  ThemeData data(Brightness forBrightness) {
    final brightness = this.brightness ?? forBrightness;
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (this == AppTheme.night) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0B0B0F),
        surfaceContainer: const Color(0xFF121218),
        surfaceContainerHigh: const Color(0xFF1A1A22),
        surfaceContainerHighest: const Color(0xFF22222C),
      );
    }
    return ThemeData(colorScheme: scheme, useMaterial3: true);
  }
}

/// Выбор оформления. Хранится только на этом устройстве, как язык.
class ThemeController extends ChangeNotifier {
  ThemeController(this._store);

  static const String _storeKey = 'ui_theme';

  final SecureKeyValueStore _store;
  AppTheme _theme = AppTheme.system;

  AppTheme get theme => _theme;

  ThemeData get light => _theme.data(Brightness.light);
  ThemeData get dark => _theme.data(Brightness.dark);

  /// Пресет задаёт светлую или тёмную тему сам; «как в системе» — по
  /// настройке устройства.
  ThemeMode get mode => switch (_theme.brightness) {
    null => ThemeMode.system,
    Brightness.light => ThemeMode.light,
    Brightness.dark => ThemeMode.dark,
  };

  Future<void> load() async {
    final stored = await _store.read(_storeKey);
    _theme = AppTheme.values.firstWhere(
      (t) => t.name == stored,
      orElse: () => AppTheme.system,
    );
    notifyListeners();
  }

  Future<void> select(AppTheme theme) async {
    await _store.write(_storeKey, theme.name);
    _theme = theme;
    notifyListeners();
  }
}
