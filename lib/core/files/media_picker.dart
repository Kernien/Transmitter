import 'file_transfer_service.dart';

/// Выбор фото или видео в Галерее — приложении для просмотра фото по
/// умолчанию. На телефоне так найти снимок проще, чем в файловом менеджере.
abstract interface class MediaPicker {
  /// Есть ли Галерея на этой платформе (сейчас — только Android).
  bool get isAvailable;

  /// Открывает Галерею для выбора одного или нескольких фото/видео.
  /// Пустой список, если пользователь ничего не выбрал.
  /// Если выбран один файл больше [maxSize], бросает `FileTooLargeException`
  /// (не читая его в память); при выборе нескольких такие файлы помечаются
  /// как [PickedFile.tooLarge].
  Future<List<PickedFile>> pickMedia({required int maxSize});
}

/// Для платформ без Галереи: там фото выбирают обычным выбором файла.
class NoMediaPicker implements MediaPicker {
  const NoMediaPicker();

  @override
  bool get isAvailable => false;

  @override
  Future<List<PickedFile>> pickMedia({required int maxSize}) async => const [];
}
