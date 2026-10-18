import 'dart:typed_data';

import '../errors/app_error.dart';

/// На устройстве нет приложения, которое открывает такие файлы.
class NoAppToOpenException implements Exception, CodedError {
  const NoAppToOpenException();

  @override
  ErrorCode get code => ErrorCode.noAppToOpen;

  @override
  Map<String, Object> get args => const {};

  @override
  String toString() => describeForLog(this);
}

/// «Открыть в другом приложении»: файл передаётся программе по умолчанию
/// (на телефоне — на выбор). Для всего, что Transmitter не показывает сам.
abstract interface class ExternalOpener {
  /// Есть ли такая возможность на платформе (в браузере — нет).
  bool get isAvailable;

  /// Бросает [NoAppToOpenException], если открыть нечем.
  Future<void> open({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  });

  /// Удаляет временные расшифрованные копии прошлых открытий.
  Future<void> cleanUp();
}

/// Для платформ, где открыть файл другим приложением нельзя (веб).
class NoExternalOpener implements ExternalOpener {
  const NoExternalOpener();

  @override
  bool get isAvailable => false;

  @override
  Future<void> open({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {}

  @override
  Future<void> cleanUp() async {}
}
