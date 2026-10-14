import 'file_transfer_service.dart';

/// Выбор фото или видео в Галерее — приложении для просмотра фото по
/// умолчанию. На телефоне так найти снимок проще, чем в файловом менеджере.
abstract interface class MediaPicker {
  /// Есть ли Галерея на этой платформе (сейчас — только Android).
  bool get isAvailable;

  /// Открывает Галерею. `null`, если пользователь ничего не выбрал.
  /// Бросает `FileTooLargeException`, если файл больше [maxSize]; в этом
  /// случае файл не читается в память.
  Future<PickedFile?> pickMedia({required int maxSize});
}

/// Для платформ без Галереи: там фото выбирают обычным выбором файла.
class NoMediaPicker implements MediaPicker {
  const NoMediaPicker();

  @override
  bool get isAvailable => false;

  @override
  Future<PickedFile?> pickMedia({required int maxSize}) async => null;
}
