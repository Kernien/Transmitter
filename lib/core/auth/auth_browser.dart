/// Показывает пользователю страницу входа облака и возвращает адрес, на
/// который облако перенаправило после входа (с `code` и `state`).
///
/// Своя реализация на каждую платформу (см. `browsers/`); выбирается в
/// `platform_auth_browser.dart`.
abstract interface class AuthBrowser {
  /// Адрес возврата для облака [providerCode]. Его нужно указать в настройках
  /// приложения в консоли разработчика облака.
  Uri redirectUriFor(String providerCode);

  Future<Uri> authenticate(Uri authorizeUrl, Uri redirectUri);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthCancelledException extends AuthException {
  const AuthCancelledException() : super('Вход отменён');
}

/// Сколько ждать, пока пользователь войдёт в облако.
const Duration authTimeout = Duration(minutes: 5);
