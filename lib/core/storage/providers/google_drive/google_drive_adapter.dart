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
  String get configurationHint =>
      'Не задан Client ID приложения Google. Укажите его в config/dev.json '
      '(см. docs/DEVELOPMENT.md, раздел «Подключение Google Drive»).';

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
}
