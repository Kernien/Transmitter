import 'dart:io';

import '../auth_browser.dart';
import 'deep_link_auth_browser.dart';
import 'loopback_auth_browser.dart';

bool get _isPhone => Platform.isAndroid || Platform.isIOS;

AuthBrowser createPlatformAuthBrowser({
  AuthPageTextsSource texts = englishAuthPageTexts,
}) => _isPhone ? DeepLinkAuthBrowser() : LoopbackAuthBrowser(texts: texts);

/// Для облаков, которые не принимают возврат по своей схеме адреса (Google):
/// везде локальный сервер, на телефоне — с кнопкой возврата в приложение.
AuthBrowser createLoopbackAuthBrowser({
  AuthPageTextsSource texts = englishAuthPageTexts,
}) => LoopbackAuthBrowser(
  texts: texts,
  returnUri: _isPhone
      ? Uri.parse(
          '${DeepLinkAuthBrowser.scheme}://${DeepLinkAuthBrowser.host}/return',
        )
      : null,
);
