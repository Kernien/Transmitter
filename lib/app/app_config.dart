/// Параметры сборки. Публичные — в `config/dev.json` (в git), секретные — в
/// `config/secrets.json` (не в git). Передаются через
/// `--dart-define-from-file=config/dev.json --dart-define-from-file=config/secrets.json`.
class AppConfig {
  const AppConfig._();

  /// App key приложения в Dropbox App Console. Не секрет: вход идёт по PKCE.
  static const String dropboxAppKey = String.fromEnvironment('DROPBOX_APP_KEY');

  /// OAuth-клиент Google типа «Desktop app» — для Windows и Android.
  static const String googleDesktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
  );

  /// Секрет клиента «Desktop app» (config/secrets.json). Может быть пустым,
  /// если Google примет вход только по PKCE.
  static const String googleDesktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
  );

  /// OAuth-клиент Google типа «Web application» — для веб-версии.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Как часто проверять облако на новые посты, пока база открыта.
  static const Duration pollInterval = Duration(seconds: 5);
}
