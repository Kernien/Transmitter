import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../blob_cache.dart';
import '../file_blob_cache.dart';

/// Кеш в системной папке кеша приложения: её может очистить система или
/// пользователь — тогда записи просто скачаются заново.
Future<DeviceCache> createPlatformBlobCache() async {
  try {
    final base = await getApplicationCacheDirectory();
    return FileBlobCache(Directory('${base.path}/transmitter_cache'));
  } catch (e) {
    debugPrint('Disk cache unavailable: $e');
    return const NoBlobCache();
  }
}
