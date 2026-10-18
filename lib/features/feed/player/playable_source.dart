// Источник для плеера на этапе компиляции: на устройствах — временный файл,
// в вебе — ссылка на данные в памяти страницы (blob:).
export 'playable_source_stub.dart'
    if (dart.library.js_interop) 'playable_source_web.dart'
    if (dart.library.io) 'playable_source_io.dart';
