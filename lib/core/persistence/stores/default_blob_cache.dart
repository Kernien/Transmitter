import '../blob_cache.dart';

/// В вебе кеша на диске нет — только в памяти сессии.
Future<DeviceCache> createPlatformBlobCache() async => const NoBlobCache();
