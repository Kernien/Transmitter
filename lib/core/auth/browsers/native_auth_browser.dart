import 'dart:io';

import '../auth_browser.dart';
import 'deep_link_auth_browser.dart';
import 'loopback_auth_browser.dart';

AuthBrowser createPlatformAuthBrowser() => Platform.isAndroid || Platform.isIOS
    ? DeepLinkAuthBrowser()
    : LoopbackAuthBrowser();
