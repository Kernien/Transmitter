// Выбор хранилища ключей и токенов на этапе компиляции: в вебе нельзя
// импортировать dart:io.
export 'stores/default_key_value_store.dart'
    if (dart.library.io) 'stores/native_key_value_store.dart';
