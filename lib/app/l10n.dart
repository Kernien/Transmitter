import 'package:flutter/widgets.dart';

import '../core/errors/app_error.dart';
import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// Короткий доступ к текстам интерфейса: `context.l10n.save`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Форматирование и тексты ошибок на языке интерфейса.
extension AppLocalizationsX on AppLocalizations {
  /// Размер файла: «512 B», «12.4 KB» / «12,4 КБ».
  String fileSize(int bytes) {
    final units = [sizeUnitB, sizeUnitKb, sizeUnitMb, sizeUnitGb];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = unit == 0 || value >= 100
        ? value.round().toString()
        : value.toStringAsFixed(1).replaceAll('.', decimalSeparator);
    return '$text ${units[unit]}';
  }

  /// Лимит размера в целых мегабайтах: «25 MB» / «25 МБ».
  String sizeLimitOf(int bytes) => sizeLimit(bytes ~/ (1024 * 1024));

  /// Текст ошибки для пользователя. Ошибки с кодом (см. ErrorCode)
  /// переводятся; остальные показываются как есть.
  String describeError(Object error) {
    if (error is FileError) {
      return '${error.fileName}: ${describeError(error.cause)}';
    }
    if (error is! CodedError) return errUnknown('$error');
    final args = error.args;
    String arg(String name) => '${args[name] ?? ''}';
    final provider = arg('provider');
    return switch (error.code) {
      ErrorCode.authCancelled => errAuthCancelled,
      ErrorCode.browserOpenFailed => errBrowserOpenFailed,
      ErrorCode.authPortBusy => errAuthPortBusy(arg('port')),
      ErrorCode.popupBlocked => errPopupBlocked,
      ErrorCode.authRejected => errAuthRejected(provider, arg('details')),
      ErrorCode.authStateMismatch => errAuthStateMismatch(provider),
      ErrorCode.authNoCode => errAuthNoCode(provider),
      ErrorCode.authTokenFailed => errAuthTokenFailed(provider, arg('details')),
      ErrorCode.authNoOfflineAccess => errAuthNoOfflineAccess(provider),
      ErrorCode.cloudNotConnected => errCloudNotConnected,
      ErrorCode.cloudSignInAgain => errCloudSignInAgain,
      ErrorCode.cloudAccessRevoked => errCloudAccessRevoked(provider),
      ErrorCode.cloudWebSessionExpired => errCloudWebSessionExpired(provider),
      ErrorCode.cloudTokenRefreshFailed => errCloudTokenRefreshFailed(
        provider,
        arg('details'),
      ),
      ErrorCode.cloudRateLimited => errCloudRateLimited(provider),
      ErrorCode.cloudQuota => errCloudQuota,
      ErrorCode.cloudFileNotFound => errCloudFileNotFound,
      ErrorCode.cloudNoUploadUrl => errCloudNoUploadUrl(provider),
      ErrorCode.cloudRequestFailed => errCloudRequestFailed(
        provider,
        arg('details'),
      ),
      ErrorCode.fileTooLarge => errFileTooLarge(
        sizeLimitOf(args['maxBytes'] as int? ?? 0),
      ),
      ErrorCode.decryptionFailed => errDecryptionFailed,
      ErrorCode.keyNotTransmitter => errKeyNotTransmitter,
      ErrorCode.keyCorrupted => errKeyCorrupted,
    };
  }
}
