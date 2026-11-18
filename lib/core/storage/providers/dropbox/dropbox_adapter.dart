import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../auth/auth_browser.dart';
import '../../../auth/oauth_credentials.dart';
import '../../../auth/oauth_token_manager.dart';
import '../../cloud_provider_adapter.dart';
import '../../cloud_provider_id.dart';
import '../../cloud_storage.dart';
import 'dropbox_authenticator.dart';
import 'dropbox_storage.dart';

class DropboxAdapter implements CloudProviderAdapter {
  DropboxAdapter({
    required String appKey,
    required AuthBrowser browser,
    required http.Client client,
  }) : _client = client,
       _auth = DropboxAuthenticator(
         appKey: appKey,
         browser: browser,
         client: client,
       );

  final http.Client _client;
  final DropboxAuthenticator _auth;

  @override
  CloudProviderId get id => CloudProviderId.dropbox;

  @override
  bool get isConfigured => _auth.appKey.isNotEmpty;

  @override
  Future<String> signIn() => _auth.signIn().then((c) => c.encode());

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) => DropboxStorage(
    client: _client,
    tokens: OAuthTokenManager(
      initial: OAuthCredentials.decode(credentials),
      refresher: _auth.refresh,
      onChanged: (c) => onCredentialsChanged(c.encode()),
    ),
  );

  @override
  Future<CloudAccountProfile?> fetchProfile(String credentials) async {
    try {
      final tokens = OAuthTokenManager(
        initial: OAuthCredentials.decode(credentials),
        refresher: _auth.refresh,
        onChanged: (_) async {},
      );
      final token = await tokens.accessToken();
      final uri = Uri.parse(
        'https://api.dropboxapi.com/2/users/get_current_account',
      );
      final response = await _client.post(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final email = json['email'] as String?;
        final name =
            (json['name'] as Map<String, dynamic>?)?['display_name'] as String?;
        return CloudAccountProfile(email: email, displayName: name);
      }
    } catch (_) {
      // Игнорируем сетевые ошибки при запросе профиля.
    }
    return null;
  }
}
