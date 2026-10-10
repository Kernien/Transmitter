import '../utils/clock.dart';
import 'oauth_credentials.dart';

typedef TokenRefresher = Future<OAuthCredentials> Function(String refreshToken);
typedef CredentialsListener = Future<void> Function(OAuthCredentials credentials);

/// Выдаёт действующий access token и обновляет его по refresh token.
///
/// Одновременные запросы на обновление объединяются в один.
class OAuthTokenManager {
  OAuthTokenManager({
    required OAuthCredentials initial,
    required this._refresher,
    this._onChanged,
    this._clock = DateTime.now,
  }) : _credentials = initial;

  OAuthCredentials _credentials;
  final TokenRefresher _refresher;
  final CredentialsListener? _onChanged;
  final Clock _clock;
  Future<String>? _refreshing;

  /// Действующий токен; если срок истекает, сначала обновляет его.
  Future<String> accessToken() async {
    if (_credentials.needsRefreshAt(_clock().toUtc())) return refresh();
    return _credentials.accessToken;
  }

  /// Принудительно обновляет токен (например, после ответа 401).
  Future<String> refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<String> _doRefresh() async {
    _credentials = await _refresher(_credentials.refreshToken);
    await _onChanged?.call(_credentials);
    return _credentials.accessToken;
  }
}
