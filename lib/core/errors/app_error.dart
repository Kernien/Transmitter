/// Коды ошибок, которые видит пользователь.
///
/// Слой core не хранит готовых текстов (он не знает языка интерфейса):
/// ошибка несёт код и параметры, а текст на нужном языке подставляет
/// интерфейс (`AppLocalizations.describeError`). Новый код — новая строка
/// `err…` в lib/l10n/*.arb.
enum ErrorCode {
  // Вход в облако.
  authCancelled,
  browserOpenFailed,
  authPortBusy, // port
  popupBlocked,
  authRejected, // provider, details
  authStateMismatch, // provider
  authNoCode, // provider
  authTokenFailed, // provider, details
  authNoOfflineAccess, // provider
  // Работа с облаком.
  cloudNotConnected,
  cloudSignInAgain,
  cloudAccessRevoked, // provider
  cloudWebSessionExpired, // provider
  cloudTokenRefreshFailed, // provider, details
  cloudRateLimited, // provider
  cloudQuota,
  cloudFileNotFound, // path
  cloudNoUploadUrl, // provider
  cloudRequestFailed, // provider, details
  cloudSharingNotAllowed, // provider — нет права на публичные ссылки
  // Файлы, шифрование, ключи.
  fileTooLarge, // maxBytes
  decryptionFailed,
  keyNotTransmitter,
  keyCorrupted,
  // Публичные доски.
  boardSignatureInvalid,
  boardClosed,
}

/// Ошибка с кодом для показа пользователю.
abstract interface class CodedError {
  ErrorCode get code;

  /// Параметры для текста: provider, details, maxBytes, port, path.
  Map<String, Object> get args;
}

/// Технический текст ошибки для журналов (не для пользователя).
String describeForLog(CodedError error) =>
    error.args.isEmpty ? error.code.name : '${error.code.name} ${error.args}';

/// Ошибка с конкретным файлом (например, перетащенным в окно): к тексту
/// причины добавляется имя файла.
class FileError implements Exception {
  const FileError(this.fileName, this.cause);

  final String fileName;
  final Object cause;

  @override
  String toString() => '$fileName: $cause';
}
