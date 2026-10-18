import 'dart:typed_data';

/// Кеш файлов на устройстве: зашифрованные записи, комментарии, опись
/// доски — в том же виде, что и в облаке, поэтому без ключа базы он
/// бесполезен. Кеш можно потерять в любой момент (система чистит место) —
/// тогда данные просто скачаются заново.
abstract interface class BlobCache {
  /// `null`, если в кеше нет.
  Future<Uint8List?> read(String key);

  Future<void> write(String key, List<int> bytes);

  /// Если нет — ничего не делает.
  Future<void> delete(String key);

  /// Отдельная область кеша (для одной базы или доски).
  BlobCache scope(String name);
}

/// Лимит на сохранённые файлы по умолчанию (как в Telegram: открытые файлы
/// хранятся, пока не кончится выделенное место).
const int defaultFileCacheLimit = 1024 * 1024 * 1024;

/// Ключ кеша для вложения.
String attachmentCacheKey(String attachmentId) => 'att-$attachmentId.bin';

bool isAttachmentCacheKey(String key) =>
    key.startsWith('att-') && key.endsWith('.bin');

/// Место на устройстве под сохранённые файлы: лимит, занятый объём, уборка.
/// Записи, комментарии и описи досок занимают мало и в лимит не входят.
abstract interface class CacheStorage {
  /// Сохранённые файлы сверх лимита удаляются — сначала давно не открытые.
  int get limitBytes;
  set limitBytes(int value);

  /// Сколько занимает весь кеш на устройстве.
  Future<int> usedBytes();

  /// Удаляет все сохранённые файлы (записи остаются).
  Future<void> clearFiles();
}

/// Корень кеша на устройстве: и хранилище, и место под файлы.
abstract interface class DeviceCache implements BlobCache, CacheStorage {
  /// Есть ли кеш на диске (в вебе — нет).
  bool get isPersistent;
}

/// Без кеша на диске (веб): всё хранится только в памяти сессии.
class NoBlobCache implements DeviceCache {
  const NoBlobCache();

  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> write(String key, List<int> bytes) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  BlobCache scope(String name) => this;

  @override
  bool get isPersistent => false;

  @override
  int get limitBytes => 0;

  @override
  set limitBytes(int value) {}

  @override
  Future<int> usedBytes() async => 0;

  @override
  Future<void> clearFiles() async {}
}

/// Кеш в памяти — для тестов.
class MemoryBlobCache implements BlobCache {
  MemoryBlobCache([Map<String, Uint8List>? entries]) : entries = entries ?? {};

  /// Все записи с полными ключами (`область/ключ`).
  final Map<String, Uint8List> entries;
  String _prefix = '';

  @override
  Future<Uint8List?> read(String key) async => entries['$_prefix$key'];

  @override
  Future<void> write(String key, List<int> bytes) async =>
      entries['$_prefix$key'] = Uint8List.fromList(bytes);

  @override
  Future<void> delete(String key) async => entries.remove('$_prefix$key');

  @override
  BlobCache scope(String name) =>
      MemoryBlobCache(entries).._prefix = '$_prefix$name/';
}
