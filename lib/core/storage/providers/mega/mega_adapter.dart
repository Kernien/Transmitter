import 'package:http/http.dart' as http;

import '../../cloud_provider_adapter.dart';
import '../../cloud_provider_id.dart';
import '../../cloud_storage.dart';
import 'mega_api.dart';
import 'mega_session.dart';
import 'mega_storage.dart';

/// MEGA: вход по почте и паролю прямо в приложении (OAuth у MEGA нет).
class MegaAdapter implements PasswordCloudAdapter {
  MegaAdapter({required http.Client client})
    : _client = client,
      _auth = MegaAuthenticator(client);

  final http.Client _client;
  final MegaAuthenticator _auth;

  /// Хранилище на сеанс: дерево узлов MEGA загружается один раз и дальше
  /// только обновляется, поэтому все базы одного аккаунта делят его.
  final Map<String, MegaStorage> _storages = {};

  @override
  CloudProviderId get id => CloudProviderId.mega;

  @override
  bool get isConfigured => true;

  @override
  Future<String> signIn() =>
      throw UnsupportedError('MEGA signs in with a password');

  @override
  Future<String> signInWithPassword({
    required String email,
    required String password,
    String? secondFactorCode,
  }) async => (await _auth.signIn(
    email: email,
    password: password,
    secondFactorCode: secondFactorCode,
  )).encode();

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) {
    final session = MegaCredentials.decode(credentials);
    return _storages.putIfAbsent(
      session.sessionId,
      () => MegaStorage(api: MegaApi(_client), credentials: session),
    );
  }
}
