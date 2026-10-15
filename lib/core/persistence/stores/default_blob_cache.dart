import '../blob_cache.dart';

/// В вебе кеша на диске нет — только в памяти сессии.
Future<BlobCache> createPlatformBlobCache() async => const NoBlobCache();
