import 'dart:typed_data';

/// Файл, которым поделились из другого приложения.
class SharedFile {
  const SharedFile({
    required this.name,
    required this.size,
    this.bytes,
    this.mimeType,
  });

  final String name;
  final int size;

  /// `null`, если файл больше предельного размера и не был прочитан.
  final Uint8List? bytes;
  final String? mimeType;

  /// Не помещается в лимит базы [limit] (или вообще не был прочитан).
  bool exceeds(int limit) => bytes == null || size > limit;
}

/// То, чем поделились: текст или ссылка и/или файлы.
class SharedContent {
  const SharedContent({this.text, this.subject, this.files = const []});

  final String? text;

  /// Заголовок (например, название страницы, когда делятся ссылкой).
  final String? subject;
  final List<SharedFile> files;

  bool get hasText => text != null && text!.trim().isNotEmpty;
  bool get isEmpty => !hasText && files.isEmpty;
}

/// Источник содержимого из системного меню «Поделиться».
abstract interface class IncomingShareSource {
  /// Каждое «Поделиться → Transmitter». Ошибки чтения приходят как ошибки потока.
  Stream<SharedContent> get shares;

  /// Вернуть пользователя в приложение, из которого он поделился.
  Future<void> returnToSourceApp();
}

/// Для платформ без меню «Поделиться» (Windows, веб).
class NoIncomingShares implements IncomingShareSource {
  const NoIncomingShares();

  @override
  Stream<SharedContent> get shares => const Stream.empty();

  @override
  Future<void> returnToSourceApp() async {}
}
