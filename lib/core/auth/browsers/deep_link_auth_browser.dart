import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth_browser.dart';

/// Вход на телефоне: страница входа открывается в браузере, а облако
/// возвращает пользователя в приложение по ссылке `app.transmitter://oauth/…`.
///
/// Схема зарегистрирована в `android/app/src/main/AndroidManifest.xml`.
class DeepLinkAuthBrowser implements AuthBrowser {
  static const String scheme = 'app.transmitter';
  static const String host = 'oauth';

  @override
  Uri redirectUriFor(String providerCode) => Uri.parse('$scheme://$host/$providerCode');

  @override
  Future<Uri> authenticate(Uri authorizeUrl, Uri redirectUri) async {
    final callback = AppLinks()
        .uriLinkStream
        .firstWhere((uri) =>
            uri.scheme == redirectUri.scheme &&
            uri.host == redirectUri.host &&
            uri.path == redirectUri.path)
        .timeout(authTimeout, onTimeout: () => throw const AuthCancelledException());

    final opened = await launchUrl(authorizeUrl, mode: LaunchMode.externalApplication);
    if (!opened) throw const AuthException('Не удалось открыть браузер');
    return callback;
  }
}
