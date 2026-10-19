import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../errors/app_error.dart';
import '../../cloud_storage.dart';
import 'mega_aes.dart';
import 'mega_api.dart';
import 'mega_crypto.dart';

/// Сеанс MEGA на этом устройстве. Пароль не хранится: после входа
/// достаточно идентификатора сеанса и мастер-ключа аккаунта.
class MegaCredentials {
  const MegaCredentials({
    required this.email,
    required this.sessionId,
    required this.masterKey,
    required this.userHandle,
  });

  factory MegaCredentials.decode(String text) {
    final json = jsonDecode(text) as Map<String, Object?>;
    return MegaCredentials(
      email: json['e'] as String,
      sessionId: json['sid'] as String,
      masterKey: MegaCrypto.unb64(json['k'] as String),
      userHandle: json['u'] as String,
    );
  }

  final String email;
  final String sessionId;
  final Uint8List masterKey;

  /// Дескриптор пользователя: по нему находится ключ узла в поле `k`.
  final String userHandle;

  String encode() => jsonEncode({
    'e': email,
    'sid': sessionId,
    'k': MegaCrypto.b64(masterKey),
    'u': userHandle,
  });
}

/// Вход в MEGA по почте и паролю (и коду 2FA, если он включён).
class MegaAuthenticator {
  MegaAuthenticator(this._client, {this.gateway = MegaApi.defaultGateway});

  final http.Client _client;
  final String gateway;

  Future<MegaCredentials> signIn({
    required String email,
    required String password,
    String? secondFactorCode,
  }) async {
    // MEGA хранит почту в нижнем регистре.
    final user = email.trim().toLowerCase();
    final api = MegaApi(_client, gateway: gateway);
    try {
      final info = await api.call({'a': 'us0', 'user': user}) as Map;
      final Uint8List passwordKey;
      final String userHash;
      switch (info['v']) {
        case 2:
          final derived = await MegaCrypto.deriveV2(
            password,
            MegaCrypto.unb64(info['s'] as String),
          );
          passwordKey = derived.passwordKey;
          userHash = derived.userHash;
        case 1:
          passwordKey = MegaCrypto.prepareKeyV1(utf8.encode(password));
          userHash = MegaCrypto.userHashV1(user, passwordKey);
        default:
          throw StorageException.request('MEGA', 'account v${info['v']}');
      }
      final code = secondFactorCode?.trim();
      final login = await api.call({
        'a': 'us',
        'user': user,
        'uh': userHash,
        if (code != null && code.isNotEmpty) 'mfa': code,
      });
      if (login is! Map || login['csid'] == null || login['k'] == null) {
        // Например, временный аккаунт без почты (tsid).
        throw StorageException.request('MEGA', 'unsupported account');
      }
      final masterKey = MegaAes(passwordKey)
          .decryptEcb(MegaCrypto.unb64(login['k'] as String));
      final sessionId = MegaCrypto.decryptSessionId(
        csid: MegaCrypto.unb64(login['csid'] as String),
        privk: MegaCrypto.unb64(login['privk'] as String),
        masterKey: masterKey,
      );
      api.sid = sessionId;
      var handle = login['u'];
      if (handle is! String) {
        final me = await api.call({'a': 'ug'}) as Map;
        handle = me['u'] as String;
      }
      return MegaCredentials(
        email: user,
        sessionId: sessionId,
        masterKey: masterKey,
        userHandle: handle,
      );
    } on MegaApiException catch (e) {
      throw _signInError(e.code, hasCode: secondFactorCode != null);
    } on FormatException {
      // Ключ не расшифровался — на деле это неверный пароль.
      throw const StorageAuthException(ErrorCode.cloudWrongPassword);
    }
  }

  static StorageException _signInError(int code, {required bool hasCode}) =>
      switch (code) {
        MegaApiException.eMfaRequired when hasCode =>
          const StorageAuthException(ErrorCode.cloudSecondFactorWrong),
        MegaApiException.eMfaRequired => const SecondFactorRequiredException(),
        MegaApiException.eFailed || MegaApiException.eExpired when hasCode =>
          const StorageAuthException(ErrorCode.cloudSecondFactorWrong),
        MegaApiException.eNoEnt || MegaApiException.eAccess =>
          const StorageAuthException(ErrorCode.cloudWrongPassword),
        MegaApiException.eBlocked => const StorageAuthException(
          ErrorCode.cloudAccountBlocked,
          {'provider': 'MEGA'},
        ),
        _ => megaStorageError(code),
      };
}

/// Ошибка MEGA → ошибка хранилища с понятным текстом.
StorageException megaStorageError(int code, {String? path}) => switch (code) {
  MegaApiException.eSid => const StorageAuthException(),
  MegaApiException.eBlocked => const StorageAuthException(
    ErrorCode.cloudAccountBlocked,
    {'provider': 'MEGA'},
  ),
  MegaApiException.eOverQuota ||
  MegaApiException.eGoingOverQuota => const StorageQuotaException(),
  MegaApiException.eRateLimit ||
  MegaApiException.eTooMany ||
  MegaApiException.eTempUnavailable => const StorageException(
    ErrorCode.cloudRateLimited,
    {'provider': 'MEGA'},
  ),
  MegaApiException.eNoEnt when path != null => StorageNotFoundException(path),
  _ => StorageException.request('MEGA', 'E$code'),
};
