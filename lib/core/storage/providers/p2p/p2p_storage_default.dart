import '../../cloud_storage.dart';
import '../../in_memory_cloud_storage.dart';

/// Заглушка хранилища для сред без файловой системы (веб).
class DefaultP2pStorage extends InMemoryCloudStorage {
  DefaultP2pStorage([Object? _]);
}

Future<CloudStorage> createPlatformP2pStorage() async => DefaultP2pStorage();
