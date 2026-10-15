import 'dart:io';
import 'dart:typed_data';

import 'blob_cache.dart';

/// Кеш в папке на диске: ключ — имя файла.
class FileBlobCache implements BlobCache {
  FileBlobCache(this.directory);

  final Directory directory;
  bool _ready = false;

  File _file(String key) => File('${directory.path}/$key');

  @override
  Future<Uint8List?> read(String key) async {
    try {
      return await _file(key).readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String key, List<int> bytes) async {
    if (!_ready) {
      await directory.create(recursive: true);
      _ready = true;
    }
    // Через временный файл: прерванная запись не оставит обрезанный файл.
    final temp = _file('$key.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(_file(key).path);
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _file(key).delete();
    } on FileSystemException {
      // Уже нет.
    }
  }

  @override
  BlobCache scope(String name) =>
      FileBlobCache(Directory('${directory.path}/$name'));
}
