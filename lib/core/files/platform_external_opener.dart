// Выбор реализации «Открыть в другом приложении» на этапе компиляции: в
// вебе нельзя импортировать dart:io.
export 'openers/default_external_opener.dart'
    if (dart.library.io) 'openers/native_external_opener.dart';
