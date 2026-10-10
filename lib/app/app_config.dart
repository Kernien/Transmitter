/// Параметры сборки. Задаются в `config/dev.json` и передаются через
/// `flutter run --dart-define-from-file=config/dev.json`.
class AppConfig {
  const AppConfig._();

  /// App key приложения в Dropbox App Console. Не секрет: вход идёт по PKCE.
  static const String dropboxAppKey = String.fromEnvironment('DROPBOX_APP_KEY');

  /// Как часто проверять облако на новые посты, пока база открыта.
  static const Duration pollInterval = Duration(seconds: 5);
}
