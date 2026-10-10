// Выбор реализации DeviceNameSuggester на этапе компиляции: в вебе нельзя
// импортировать dart:io.
export 'suggesters/fallback_device_name_suggester.dart'
    if (dart.library.js_interop) 'suggesters/web_device_name_suggester.dart'
    if (dart.library.io) 'suggesters/native_device_name_suggester.dart';
