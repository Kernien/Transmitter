import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../auth/auth_browser.dart';
import '../../../errors/app_error.dart';
import '../../../auth/oauth_credentials.dart';
import '../../../auth/pkce.dart';
import '../../../utils/clock.dart';
import '../../cloud_storage.dart';

/// Вход в Dropbox по OAuth 2 (authorization code + PKCE, без секрета клиента)
/// и обновление токена.
class DropboxAuthenticator {
  DropboxAuthenticator({
    required this.appKey,
    required this._browser,
    required this._client,
    this._clock = DateTime.now,
  });

  static const String providerCode = 'dropbox';
  static const String _provider = 'Dropbox';
  static final Uri _authorizeUrl = Uri.https(
    'www.dropbox.com',
    '/oauth2/authorize',
  );
  static final Uri _tokenUrl = Uri.https('api.dropboxapi.com', '/oauth2/token');

  final String appKey;
  final AuthBrowser _browser;
  final http.Client _client;
  final Clock _clock;

  Future<OAuthCredentials> signIn() async {
    // До вызова authenticate не должно быть await (см. WebAuthBrowser).
    final pkce = Pkce.generate();
    final state = randomUrlSafeString(32);
    final redirectUri = _browser.redirectUriFor(providerCode);
    final authorizeUrl = _authorizeUrl.replace(
      queryParameters: {
        'client_id': appKey,
        'response_type': 'code',
        'code_challenge': pkce.challenge,
        'code_challenge_method': Pkce.method,
        'token_access_type': 'offline',
        'redirect_uri': redirectUri.toString(),
        'state': state,
      },
    );

    final callback = await _browser.authenticate(authorizeUrl, redirectUri);
    final params = callback.queryParameters;

    final error = params['error'];
    if (error == 'access_denied') throw const AuthCancelledException();
    if (error != null) {
      throw AuthException(ErrorCode.authRejected, {
        'provider': _provider,
        'details': params['error_description'] ?? error,
      });
    }
    if (params['state'] != state) {
      throw const AuthException(ErrorCode.authStateMismatch, {
        'provider': _provider,
      });
    }
    final code = params['code'];
    if (code == null) {
      throw const AuthException(ErrorCode.authNoCode, {'provider': _provider});
    }

    final response = await _client.post(
      _tokenUrl,
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': appKey,
        'code_verifier': pkce.verifier,
        'redirect_uri': redirectUri.toString(),
      },
    );
    if (response.statusCode != 200) {
      throw AuthException(ErrorCode.authTokenFailed, {
        'provider': _provider,
        'details': '${response.statusCode}',
      });
    }
    return _parse(response.body);
  }

  /// Бросает [StorageAuthException], если доступ отозван и нужен новый вход.
  Future<OAuthCredentials> refresh(String refreshToken) async {
    final response = await _client.post(
      _tokenUrl,
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': appKey,
      },
    );
    if (response.statusCode == 400 || response.statusCode == 401) {
      throw const StorageAuthException(ErrorCode.cloudAccessRevoked, {
        'provider': _provider,
      });
    }
    if (response.statusCode != 200) {
      throw StorageException(ErrorCode.cloudTokenRefreshFailed, {
        'provider': _provider,
        'details': '${response.statusCode}',
      });
    }
    // При обновлении Dropbox не присылает новый refresh token — оставляем старый.
    return _parse(response.body, fallbackRefreshToken: refreshToken);
  }

  OAuthCredentials _parse(String body, {String? fallbackRefreshToken}) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final refreshToken =
        (json['refresh_token'] as String?) ?? fallbackRefreshToken;
    if (refreshToken == null) {
      throw const AuthException(ErrorCode.authNoOfflineAccess, {
        'provider': _provider,
      });
    }
    return OAuthCredentials(
      accessToken: json['access_token'] as String,
      refreshToken: refreshToken,
      expiresAt: _clock().toUtc().add(
        Duration(seconds: (json['expires_in'] as num).toInt()),
      ),
    );
  }
}
