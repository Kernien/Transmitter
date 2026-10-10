import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../auth_browser.dart';

AuthBrowser createPlatformAuthBrowser() => WebAuthBrowser();

/// Вход в веб-версии: страница входа открывается во всплывающем окне, облако
/// возвращает его на `auth.html`, а та передаёт адрес обратно приложению.
///
/// Используются два канала: `postMessage` и событие `storage` (если облако
/// разорвало связь окна с приложением через Cross-Origin-Opener-Policy).
class WebAuthBrowser implements AuthBrowser {
  static const String messageKey = 'transmitter-oauth';

  @override
  Uri redirectUriFor(String providerCode) => Uri.base.resolve('auth.html');

  @override
  Future<Uri> authenticate(Uri authorizeUrl, Uri redirectUri) {
    // window.open вызывается синхронно, в обработчике нажатия кнопки,
    // иначе браузер заблокирует всплывающее окно.
    final popup = web.window.open(
      authorizeUrl.toString(),
      'transmitter_auth',
      'popup,width=600,height=760',
    );
    if (popup == null) {
      return Future.error(const AuthException(
        'Браузер заблокировал всплывающее окно. Разрешите всплывающие окна для этого сайта.',
      ));
    }

    final result = Completer<Uri>();
    void complete(String? href) {
      if (href == null || result.isCompleted) return;
      final uri = Uri.parse(href);
      if (uri.path == redirectUri.path) result.complete(uri);
    }

    final onMessage = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin) return;
      final data = event.data.dartify();
      if (data is Map) complete(data[messageKey] as String?);
    }).toJS;

    final onStorage = ((web.StorageEvent event) {
      if (event.key != messageKey) return;
      complete(event.newValue);
      web.window.localStorage.removeItem(messageKey);
    }).toJS;

    web.window.addEventListener('message', onMessage);
    web.window.addEventListener('storage', onStorage);

    return result.future
        .timeout(authTimeout, onTimeout: () => throw const AuthCancelledException())
        .whenComplete(() {
      web.window.removeEventListener('message', onMessage);
      web.window.removeEventListener('storage', onStorage);
    });
  }
}
