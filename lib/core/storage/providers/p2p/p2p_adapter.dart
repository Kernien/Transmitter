import '../../cloud_provider_adapter.dart';
import '../../cloud_provider_id.dart';
import '../../cloud_storage.dart';

/// Адаптер локального хранилища P2P-досок.
class P2pAdapter implements CloudProviderAdapter {
  P2pAdapter({required this.storage});

  final CloudStorage storage;

  @override
  CloudProviderId get id => CloudProviderId.p2p;

  @override
  bool get isConfigured => true;

  @override
  Future<String> signIn() async => 'local_p2p';

  @override
  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  }) => storage;

  @override
  Future<CloudAccountProfile?> fetchProfile(String credentials) async =>
      const CloudAccountProfile(displayName: 'P2P');
}
