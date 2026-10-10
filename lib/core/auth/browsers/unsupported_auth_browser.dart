import '../auth_browser.dart';

AuthBrowser createPlatformAuthBrowser() =>
    throw UnsupportedError('Вход в облако не поддерживается на этой платформе');

AuthBrowser createLoopbackAuthBrowser() => createPlatformAuthBrowser();
