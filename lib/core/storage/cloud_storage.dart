import 'dart:typed_data';

import '../errors/app_error.dart';

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

/// Ошибка облака. Текст для пользователя — по [code] (см. ErrorCode).
class StorageException implements Exception, CodedError {
  const StorageException(this.code, [this.args = const {}]);

  /// Ошибка запроса к облаку: [details] — HTTP-код и ответ сервера.
  StorageException.request(String provider, String details)
    : this(ErrorCode.cloudRequestFailed, {
        'provider': provider,
        'details': details,
      });

  @override
  final ErrorCode code;

  @override
  final Map<String, Object> args;

  @override
  String toString() => describeForLog(this);
}

/// Нужен новый вход в облако: токен недействителен, отозван или (в вебе)
/// истёк временный доступ.
class StorageAuthException extends StorageException {
  const StorageAuthException([
    super.code = ErrorCode.cloudSignInAgain,
    super.args,
  ]);
}

class StorageNotFoundException extends StorageException {
  StorageNotFoundException(String path)
    : super(ErrorCode.cloudFileNotFound, {'path': path});
}

class StorageQuotaException extends StorageException {
  const StorageQuotaException() : super(ErrorCode.cloudQuota);
}
