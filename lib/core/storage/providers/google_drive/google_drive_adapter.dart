import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../auth/auth_browser.dart';
import '../../../auth/oauth_credentials.dart';
import '../../../auth/oauth_token_manager.dart';
import '../../cloud_provider_adapter.dart';
import '../../cloud_provider_id.dart';
import '../../cloud_storage.dart';
import 'google_drive_authenticator.dart';
import 'google_drive_storage.dart';

class GoogleDriveAdapter implements CloudProviderAdapter {
  GoogleDriveAdapter({
    required String clientId,
    String clientSecret = '',
    required bool browserFlow,
    required AuthBrowser browser,
    required this._client,
  }) : _auth = GoogleDriveAuthenticator(
         clientId: clientId,
         clientSecret: clientSecret,
         browserFlow: browserFlow,
         browser: browser,
         client: _client,
       );

  final http.Client _client;
  final GoogleDriveAuthenticator _auth;

  @override
  CloudProviderId get id => CloudProviderId.googleDrive;

  @override
  bool get isConfigured => _auth.clientId.isNotEmpty;

  @override
  Future<String> signIn() => _auth.signIn().then((c) => c.encode());

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) => GoogleDriveStorage(
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
        'https://www.googleapis.com/drive/v3/about?fields=user(displayName,emailAddress)',
      );
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final user = json['user'] as Map<String, dynamic>?;
        if (user != null) {
          final email = user['emailAddress'] as String?;
          final name = user['displayName'] as String?;
          return CloudAccountProfile(email: email, displayName: name);
        }
      }
    } catch (_) {
      // Игнорируем сетевые ошибки при запросе профиля.
    }
    return null;
  }
}
