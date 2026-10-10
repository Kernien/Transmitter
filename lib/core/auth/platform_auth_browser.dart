// Выбор реализации AuthBrowser для текущей платформы на этапе компиляции:
// в вебе нельзя импортировать dart:io, а на устройствах — package:web.
export 'browsers/unsupported_auth_browser.dart'
    if (dart.library.js_interop) 'browsers/web_auth_browser.dart'
    if (dart.library.io) 'browsers/native_auth_browser.dart';
