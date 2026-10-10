import 'dart:typed_data';

/// Файл в облачном хранилище.
class RemoteFile {
  const RemoteFile({required this.name, required this.size});

  final String name;
  final int size;
}

/// Минимальный набор операций, который требуется от любого облака.
///
/// Пути относительные, с разделителем `/`, и отсчитываются от папки
/// приложения в облаке пользователя. Реализация сама переводит их в формат
/// своего API. Содержимое к этому моменту уже зашифровано, хранилище работает
/// только с непрозрачными байтами.
abstract interface class CloudStorage {
  /// Создаёт папку вместе с родительскими. Если папка уже есть, ничего не делает.
  Future<void> ensureFolder(String path);

  /// Файлы, лежащие прямо в [folder]. Если папки нет, возвращает пустой список.
  Future<List<RemoteFile>> listFiles(String folder);

  /// Загружает файл, перезаписывая существующий.
  Future<void> upload(String path, Uint8List bytes);

  /// Бросает [StorageNotFoundException], если файла нет.
  Future<Uint8List> download(String path);

  /// Удаляет файл. Если файла нет, ничего не делает.
  Future<void> delete(String path);
}

class StorageException implements Exception {
  const StorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Токен доступа к облаку недействителен или просрочен.
class StorageAuthException extends StorageException {
  const StorageAuthException([super.message = 'Нужно заново войти в облако']);
}

class StorageNotFoundException extends StorageException {
  const StorageNotFoundException(String path) : super('Файл не найден: $path');
}

class StorageQuotaException extends StorageException {
  const StorageQuotaException([super.message = 'В облаке закончилось место']);
}
