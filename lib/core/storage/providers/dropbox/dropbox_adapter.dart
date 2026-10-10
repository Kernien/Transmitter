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
  String get configurationHint =>
      'Не задан App key приложения Dropbox. Укажите его в config/dev.json '
      '(см. README, раздел «Подключение Dropbox»).';

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
}
