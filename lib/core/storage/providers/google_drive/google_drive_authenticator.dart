import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../auth/auth_browser.dart';
import '../../../auth/oauth_credentials.dart';
import '../../../auth/pkce.dart';
import '../../../errors/app_error.dart';
import '../../../utils/clock.dart';
import '../../cloud_storage.dart';

/// Вход в Google Drive.
///
/// На устройствах (Windows, Android) — authorization code + PKCE с OAuth-
/// клиентом типа «Desktop app» и возвратом на http://127.0.0.1:47819/:
/// Google выдаёт refresh token, повторно входить не нужно. Свой адрес
/// `app.transmitter://` Google на Android не принимает.
///
/// В браузере Google выдаёт приложениям без сервера только временный
/// токен (неявный поток, около часа) — потом нужно войти снова.
class GoogleDriveAuthenticator {
  GoogleDriveAuthenticator({
    required this.clientId,
    this.clientSecret = '',
    required this.browserFlow,
    required this._browser,
    required this._client,
    this._clock = DateTime.now,
  });

  static const String providerCode = 'google';
  static const String _provider = 'Google Drive';
  static const Map<String, Object> _providerArgs = {'provider': _provider};
  static const String scope = 'https://www.googleapis.com/auth/drive.file';
  static final Uri _authorizeUrl = Uri.https(
    'accounts.google.com',
    '/o/oauth2/v2/auth',
  );
  static final Uri _tokenUrl = Uri.https('oauth2.googleapis.com', '/token');

  /// Адрес возврата для клиента «Desktop app» (порт LoopbackAuthBrowser).
  static final Uri loopbackRedirect = Uri.parse('http://127.0.0.1:47819/');

  final String clientId;

  /// Секрет клиента «Desktop app». Google не считает его настоящим секретом
  /// для устанавливаемых приложений, но в публичный репозиторий не кладём.
  final String clientSecret;

  /// `true` в веб-версии: временный токен без refresh token.
  final bool browserFlow;

  final AuthBrowser _browser;
  final http.Client _client;
  final Clock _clock;

  Future<OAuthCredentials> signIn() =>
      browserFlow ? _signInBrowser() : _signInWithCode();

  Future<OAuthCredentials> _signInWithCode() async {
    // До вызова authenticate не должно быть await (см. WebAuthBrowser).
    final pkce = Pkce.generate();
    final state = randomUrlSafeString(32);
    final url = _authorizeUrl.replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': loopbackRedirect.toString(),
        'response_type': 'code',
        'scope': scope,
        'code_challenge': pkce.challenge,
        'code_challenge_method': Pkce.method,
        'state': state,
        // offline + consent: Google выдаёт refresh token при каждом входе.
        'access_type': 'offline',
        'prompt': 'consent',
      },
    );

    final params = _checked(
      (await _browser.authenticate(url, loopbackRedirect)).queryParameters,
      state,
    );
    final code =
        params['code'] ??
        (throw const AuthException(ErrorCode.authNoCode, _providerArgs));

    final response = await _client.post(
      _tokenUrl,
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
        'redirect_uri': loopbackRedirect.toString(),
        'code_verifier': pkce.verifier,
      },
    );
    if (response.statusCode != 200) {
      throw AuthException(ErrorCode.authTokenFailed, {
        'provider': _provider,
        'details': '${response.statusCode}: ${_error(response)}',
      });
    }
    return _parse(response.body);
  }

  Future<OAuthCredentials> _signInBrowser() async {
    final state = randomUrlSafeString(32);
    final redirect = _browser.redirectUriFor(providerCode);
    final url = _authorizeUrl.replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirect.toString(),
        'response_type': 'token',
        'scope': scope,
        'state': state,
        'include_granted_scopes': 'true',
      },
    );

    final callback = await _browser.authenticate(url, redirect);
    // Неявный поток возвращает параметры во фрагменте (#access_token=…).
    final params = _checked(Uri.splitQueryString(callback.fragment), state);
    final token =
        params['access_token'] ??
        (throw const AuthException(ErrorCode.authNoCode, _providerArgs));
    final expiresIn = int.tryParse(params['expires_in'] ?? '') ?? 3600;
    return OAuthCredentials(
      accessToken: token,
      refreshToken: '',
      expiresAt: _clock().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  /// Бросает [StorageAuthException], если доступ отозван или (в браузере)
  /// временный токен истёк — нужен новый вход.
  Future<OAuthCredentials> refresh(String refreshToken) async {
    if (refreshToken.isEmpty) {
      throw const StorageAuthException(
        ErrorCode.cloudWebSessionExpired,
        _providerArgs,
      );
    }
    final response = await _client.post(
      _tokenUrl,
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      },
    );
    if (response.statusCode == 400 || response.statusCode == 401) {
      throw const StorageAuthException(
        ErrorCode.cloudAccessRevoked,
        _providerArgs,
      );
    }
    if (response.statusCode != 200) {
      throw StorageException(ErrorCode.cloudTokenRefreshFailed, {
        'provider': _provider,
        'details': '${response.statusCode}',
      });
    }
    // При обновлении Google не присылает новый refresh token — оставляем старый.
    return _parse(response.body, fallbackRefreshToken: refreshToken);
  }

  static Map<String, String> _checked(
    Map<String, String> params,
    String state,
  ) {
    final error = params['error'];
    if (error == 'access_denied') throw const AuthCancelledException();
    if (error != null) {
      throw AuthException(ErrorCode.authRejected, {
        'provider': _provider,
        'details': error,
      });
    }
    if (params['state'] != state) {
      throw const AuthException(ErrorCode.authStateMismatch, _providerArgs);
    }
    return params;
  }

  OAuthCredentials _parse(String body, {String? fallbackRefreshToken}) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final refreshToken =
        (json['refresh_token'] as String?) ?? fallbackRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthException(ErrorCode.authNoOfflineAccess, _providerArgs);
    }
    return OAuthCredentials(
      accessToken: json['access_token'] as String,
      refreshToken: refreshToken,
      expiresAt: _clock().toUtc().add(
        Duration(seconds: (json['expires_in'] as num).toInt()),
      ),
    );
  }

  static String _error(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map;
      return (json['error_description'] ?? json['error'] ?? '').toString();
    } catch (_) {
      return response.body;
    }
  }
}
