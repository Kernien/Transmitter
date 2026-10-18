import 'package:flutter/foundation.dart';

import '../core/persistence/blob_cache.dart';
import '../core/persistence/key_value_store.dart';

/// «Место на устройстве»: лимит на сохранённые файлы (выбор хранится на
/// устройстве), занятый объём, очистка.
class CacheSettings extends ChangeNotifier {
  CacheSettings(this._cache, this._store);

  static const String _storeKey = 'file_cache_limit';
  static const int _mb = 1024 * 1024;

  /// Варианты лимита.
  static const List<int> limitOptions = [
    500 * _mb,
    1024 * _mb,
    2048 * _mb,
    5120 * _mb,
  ];

  final DeviceCache _cache;
  final SecureKeyValueStore _store;

  /// Есть ли кеш на диске (в вебе — нет, и настройка не показывается).
  bool get isAvailable => _cache.isPersistent;

  int get limitBytes => _cache.limitBytes;

  Future<void> load() async {
    final saved = int.tryParse(await _store.read(_storeKey) ?? '');
    if (saved != null && limitOptions.contains(saved)) {
      _cache.limitBytes = saved;
    }
  }

  Future<void> setLimit(int bytes) async {
    _cache.limitBytes = bytes;
    await _store.write(_storeKey, '$bytes');
    notifyListeners();
  }

  Future<int> usedBytes() => _cache.usedBytes();

  Future<void> clearFiles() async {
    await _cache.clearFiles();
    notifyListeners();
  }
}
