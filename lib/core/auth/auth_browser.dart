import '../errors/app_error.dart';

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

/// Ошибка входа в облако. Текст для пользователя — по [code].
class AuthException implements Exception, CodedError {
  const AuthException(this.code, [this.args = const {}]);

  @override
  final ErrorCode code;

  @override
  final Map<String, Object> args;

  @override
  String toString() => describeForLog(this);
}

class AuthCancelledException extends AuthException {
  const AuthCancelledException() : super(ErrorCode.authCancelled);
}

/// Тексты страницы «Вход выполнен», которую показывает локальный сервер
/// входа. Передаются снаружи на языке интерфейса (core не знает языка).
class AuthPageTexts {
  const AuthPageTexts({
    required this.title,
    required this.closeHint,
    required this.returnLabel,
  });

  static const english = AuthPageTexts(
    title: 'Signed in',
    closeHint: 'You can close this tab and return to Transmitter.',
    returnLabel: 'Return to Transmitter',
  );

  final String title;
  final String closeHint;
  final String returnLabel;
}

/// Источник текстов страницы входа: вызывается при каждом показе, поэтому
/// смена языка в приложении применяется сразу.
typedef AuthPageTextsSource = AuthPageTexts Function();

AuthPageTexts englishAuthPageTexts() => AuthPageTexts.english;

/// Сколько ждать, пока пользователь войдёт в облако.
const Duration authTimeout = Duration(minutes: 5);
