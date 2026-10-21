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
  night(Colors.deepPurple, Brightness.dark),

  // Популярные тёмные темы редакторов кода — с их родными цветами.
  dracula(Color(0xFFBD93F9), Brightness.dark, _dracula),
  nord(Color(0xFF88C0D0), Brightness.dark, _nord),
  oneDark(Color(0xFF61AFEF), Brightness.dark, _oneDark),
  solarized(Color(0xFF268BD2), Brightness.dark, _solarized),
  gruvbox(Color(0xFFFABD2F), Brightness.dark, _gruvbox),
  catppuccin(Color(0xFFCBA6F7), Brightness.dark, _catppuccin);

  const AppTheme(this.seed, this.brightness, [this.palette]);

  /// Основной цвет, из которого строится палитра.
  final Color seed;

  /// `null` — как в системе.
  final Brightness? brightness;

  /// Точные цвета темы; `null` — палитра строится из [seed].
  final ThemePalette? palette;

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
    final palette = this.palette;
    if (palette != null) scheme = palette.apply(scheme, seed);
    return ThemeData(colorScheme: scheme, useMaterial3: true);
  }
}

/// Цвета готовой тёмной темы: фоны от самого тёмного к светлому, текст и
/// акценты. Остальные цвета Material берутся из палитры по [AppTheme.seed].
class ThemePalette {
  const ThemePalette({
    required this.backgrounds,
    required this.text,
    required this.dimText,
    required this.comment,
    required this.secondary,
    required this.error,
  });

  /// Пять фонов: самый тёмный, тёмный, основной, приподнятый, верхний.
  final List<Color> backgrounds;
  final Color text;
  final Color dimText;

  /// Цвет комментариев в коде — для рамок.
  final Color comment;
  final Color secondary;
  final Color error;

  /// [accent] — основной цвет темы, ставится как есть (без подбора тона).
  ColorScheme apply(ColorScheme scheme, Color accent) {
    final [darkest, dark, base, raised, highest] = backgrounds;
    Color tint(Color accent) => Color.alphaBlend(accent.withAlpha(0x59), base);
    return scheme.copyWith(
      surface: base,
      surfaceDim: dark,
      surfaceBright: raised,
      surfaceContainerLowest: darkest,
      surfaceContainerLow: dark,
      surfaceContainer: Color.lerp(base, raised, 0.5),
      surfaceContainerHigh: raised,
      surfaceContainerHighest: highest,
      onSurface: text,
      onSurfaceVariant: dimText,
      outline: comment,
      outlineVariant: highest,
      primary: accent,
      onPrimary: darkest,
      primaryContainer: tint(accent),
      onPrimaryContainer: text,
      secondary: secondary,
      onSecondary: darkest,
      secondaryContainer: tint(secondary),
      onSecondaryContainer: text,
      error: error,
      onError: darkest,
      inverseSurface: text,
      onInverseSurface: base,
    );
  }
}

const _dracula = ThemePalette(
  backgrounds: [
    Color(0xFF191A21),
    Color(0xFF21222C),
    Color(0xFF282A36),
    Color(0xFF343746),
    Color(0xFF44475A),
  ],
  text: Color(0xFFF8F8F2),
  dimText: Color(0xFFBFBFB6),
  comment: Color(0xFF6272A4),
  secondary: Color(0xFFFF79C6),
  error: Color(0xFFFF5555),
);

const _nord = ThemePalette(
  backgrounds: [
    Color(0xFF242933),
    Color(0xFF2B303B),
    Color(0xFF2E3440),
    Color(0xFF3B4252),
    Color(0xFF434C5E),
  ],
  text: Color(0xFFECEFF4),
  dimText: Color(0xFFD8DEE9),
  comment: Color(0xFF616E88),
  secondary: Color(0xFF81A1C1),
  error: Color(0xFFBF616A),
);

const _oneDark = ThemePalette(
  backgrounds: [
    Color(0xFF1B1D23),
    Color(0xFF21252B),
    Color(0xFF282C34),
    Color(0xFF2C313A),
    Color(0xFF3E4451),
  ],
  text: Color(0xFFDCDFE4),
  dimText: Color(0xFFABB2BF),
  comment: Color(0xFF5C6370),
  secondary: Color(0xFFC678DD),
  error: Color(0xFFE06C75),
);

const _solarized = ThemePalette(
  backgrounds: [
    Color(0xFF001E26),
    Color(0xFF00252F),
    Color(0xFF002B36),
    Color(0xFF073642),
    Color(0xFF0D4250),
  ],
  text: Color(0xFF93A1A1),
  dimText: Color(0xFF839496),
  comment: Color(0xFF586E75),
  secondary: Color(0xFF2AA198),
  error: Color(0xFFDC322F),
);

const _gruvbox = ThemePalette(
  backgrounds: [
    Color(0xFF1D2021),
    Color(0xFF232323),
    Color(0xFF282828),
    Color(0xFF3C3836),
    Color(0xFF504945),
  ],
  text: Color(0xFFEBDBB2),
  dimText: Color(0xFFD5C4A1),
  comment: Color(0xFF928374),
  secondary: Color(0xFF8EC07C),
  error: Color(0xFFFB4934),
);

const _catppuccin = ThemePalette(
  backgrounds: [
    Color(0xFF11111B),
    Color(0xFF181825),
    Color(0xFF1E1E2E),
    Color(0xFF313244),
    Color(0xFF45475A),
  ],
  text: Color(0xFFCDD6F4),
  dimText: Color(0xFFBAC2DE),
  comment: Color(0xFF6C7086),
  secondary: Color(0xFF89B4FA),
  error: Color(0xFFF38BA8),
);

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
