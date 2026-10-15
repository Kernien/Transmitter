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

/// Без кеша на диске (веб): всё хранится только в памяти сессии.
class NoBlobCache implements BlobCache {
  const NoBlobCache();

  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> write(String key, List<int> bytes) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  BlobCache scope(String name) => this;
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
