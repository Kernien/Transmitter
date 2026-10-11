import '../auth_browser.dart';

AuthBrowser createPlatformAuthBrowser({
  AuthPageTextsSource texts = englishAuthPageTexts,
}) => throw UnsupportedError('Cloud sign-in is not supported on this platform');

AuthBrowser createLoopbackAuthBrowser({
  AuthPageTextsSource texts = englishAuthPageTexts,
}) => createPlatformAuthBrowser();
