// Выбор кеша файлов на этапе компиляции: в вебе нельзя импортировать
// dart:io.
export 'stores/default_blob_cache.dart'
    if (dart.library.io) 'stores/native_blob_cache.dart';
