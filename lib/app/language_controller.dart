import 'package:flutter/widgets.dart';

import '../core/persistence/key_value_store.dart';
import '../l10n/app_localizations.dart';

/// Язык интерфейса, выбранный пользователем.
enum AppLanguage {
  /// Как в системе (русский или английский; для остальных языков — английский).
  system(null),
  ru('ru'),
  en('en');

  const AppLanguage(this.code);

  final String? code;

  /// Название языка на нём самом — его легко найти в списке, даже если
  /// текущий язык интерфейса непонятен.
  String get nativeName => switch (this) {
    AppLanguage.system => '',
    AppLanguage.ru => 'Русский',
    AppLanguage.en => 'English',
  };
}

/// Выбор языка интерфейса. Хранится только на этом устройстве.
class LanguageController extends ChangeNotifier {
  LanguageController(this._store, {List<Locale> Function()? systemLocales})
    : _systemLocales =
          systemLocales ??
          (() => WidgetsBinding.instance.platformDispatcher.locales);

  static const String _storeKey = 'ui_language';

  final SecureKeyValueStore _store;
  final List<Locale> Function() _systemLocales;
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;

  /// Язык для MaterialApp; `null` — как в системе.
  Locale? get locale => _language.code == null ? null : Locale(_language.code!);

  /// Действующие тексты — для мест вне виджетов (страница входа в браузере,
  /// диалог сохранения файла, подсказка имени устройства).
  AppLocalizations get current => lookupAppLocalizations(
    locale ??
        basicLocaleListResolution(
          _systemLocales(),
          AppLocalizations.supportedLocales,
        ),
  );

  Future<void> load() async {
    final stored = await _store.read(_storeKey);
    _language = AppLanguage.values.firstWhere(
      (l) => l.name == stored,
      orElse: () => AppLanguage.system,
    );
    notifyListeners();
  }

  Future<void> select(AppLanguage language) async {
    await _store.write(_storeKey, language.name);
    _language = language;
    notifyListeners();
  }
}
