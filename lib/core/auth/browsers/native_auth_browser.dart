import 'dart:io';

import '../auth_browser.dart';
import 'deep_link_auth_browser.dart';
import 'loopback_auth_browser.dart';

AuthBrowser createPlatformAuthBrowser() => Platform.isAndroid || Platform.isIOS
    ? DeepLinkAuthBrowser()
    : LoopbackAuthBrowser();

/// Для облаков, которые не принимают возврат по своей схеме адреса (Google):
/// везде локальный сервер, на телефоне — с кнопкой возврата в приложение.
AuthBrowser createLoopbackAuthBrowser() => LoopbackAuthBrowser(
  returnUri: Platform.isAndroid || Platform.isIOS
      ? Uri.parse(
          '${DeepLinkAuthBrowser.scheme}://${DeepLinkAuthBrowser.host}/return',
        )
      : null,
);
