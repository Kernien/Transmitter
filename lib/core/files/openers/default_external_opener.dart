import '../external_opener.dart';

/// В браузере файл можно только сохранить.
ExternalOpener createPlatformExternalOpener() => const NoExternalOpener();
