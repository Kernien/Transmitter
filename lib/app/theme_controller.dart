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
  catppuccin(Color(0xFFCBA6F7), Brightness.dark, _catppuccin),
  tokyoNight(Color(0xFF7AA2F7), Brightness.dark, _tokyoNight),
  monokai(Color(0xFFA6E22E), Brightness.dark, _monokai),
  githubDark(Color(0xFF58A6FF), Brightness.dark, _githubDark),
  rosePine(Color(0xFFC4A7E7), Brightness.dark, _rosePine),
  ayuMirage(Color(0xFFFFCC66), Brightness.dark, _ayuMirage),
  everforest(Color(0xFFA7C080), Brightness.dark, _everforest),

  /// Неоновый стиль Vice City в честь GTA VI: закатный розовый, бирюза и сумеречное небо.
  viceCity(Color(0xFFFF5C8D), Brightness.dark, _viceCity);

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
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Зоны окна различаются тоном фона: шапка и панель ввода — чуть светлее
      // ленты, карточки — ещё светлее, боковая панель (см. VaultsScreen) —
      // темнее. Без этого всё сливается в один цвет.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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

const _tokyoNight = ThemePalette(
  backgrounds: [
    Color(0xFF13141C),
    Color(0xFF16161E),
    Color(0xFF1A1B26),
    Color(0xFF24283B),
    Color(0xFF2F334D),
  ],
  text: Color(0xFFC0CAF5),
  dimText: Color(0xFFA9B1D6),
  comment: Color(0xFF565F89),
  secondary: Color(0xFFBB9AF7),
  error: Color(0xFFF7768E),
);

const _monokai = ThemePalette(
  backgrounds: [
    Color(0xFF171814),
    Color(0xFF1E1F1C),
    Color(0xFF272822),
    Color(0xFF3E3D32),
    Color(0xFF49483E),
  ],
  text: Color(0xFFF8F8F2),
  dimText: Color(0xFFCFCFC2),
  comment: Color(0xFF75715E),
  secondary: Color(0xFF66D9EF),
  error: Color(0xFFF92672),
);

const _githubDark = ThemePalette(
  backgrounds: [
    Color(0xFF010409),
    Color(0xFF090C10),
    Color(0xFF0D1117),
    Color(0xFF161B22),
    Color(0xFF21262D),
  ],
  text: Color(0xFFE6EDF3),
  dimText: Color(0xFF9DA7B3),
  comment: Color(0xFF6E7681),
  secondary: Color(0xFFBC8CFF),
  error: Color(0xFFF85149),
);

const _rosePine = ThemePalette(
  backgrounds: [
    Color(0xFF13111D),
    Color(0xFF16141F),
    Color(0xFF191724),
    Color(0xFF1F1D2E),
    Color(0xFF26233A),
  ],
  text: Color(0xFFE0DEF4),
  dimText: Color(0xFF908CAA),
  comment: Color(0xFF6E6A86),
  secondary: Color(0xFFEBBCBA),
  error: Color(0xFFEB6F92),
);

const _ayuMirage = ThemePalette(
  backgrounds: [
    Color(0xFF171B24),
    Color(0xFF1B202A),
    Color(0xFF1F2430),
    Color(0xFF242B38),
    Color(0xFF2D3544),
  ],
  text: Color(0xFFCCCAC2),
  dimText: Color(0xFFB3B1AD),
  comment: Color(0xFF707A8C),
  secondary: Color(0xFF73D0FF),
  error: Color(0xFFF28779),
);

const _everforest = ThemePalette(
  backgrounds: [
    Color(0xFF232A2E),
    Color(0xFF272E33),
    Color(0xFF2D353B),
    Color(0xFF343F44),
    Color(0xFF3D484D),
  ],
  text: Color(0xFFD3C6AA),
  dimText: Color(0xFF9DA9A0),
  comment: Color(0xFF859289),
  secondary: Color(0xFF7FBBB3),
  error: Color(0xFFE67E80),
);

const _viceCity = ThemePalette(
  backgrounds: [
    Color(0xFF100C22),
    Color(0xFF15102C),
    Color(0xFF1D1739),
    Color(0xFF261F49),
    Color(0xFF332A5E),
  ],
  text: Color(0xFFFDF0F8),
  dimText: Color(0xFFC0AECF),
  comment: Color(0xFF70568C),
  secondary: Color(0xFF00F0FF),
  error: Color(0xFFFF4D6D),
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
