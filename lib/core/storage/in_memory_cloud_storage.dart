import 'dart:typed_data';

import 'cloud_storage.dart';

/// Хранилище в памяти: используется в тестах вместо реального облака.
class InMemoryCloudStorage implements CloudStorage {
  final Map<String, Uint8List> files = {};
  final Set<String> folders = {};

  @override
  Future<void> ensureFolder(String path) async {
    final parts = _segments(path);
    for (var i = 1; i <= parts.length; i++) {
      folders.add(parts.take(i).join('/'));
    }
  }

  @override
  Future<List<RemoteFile>> listFiles(String folder) async {
    final prefix = _normalize(folder);
    return [
      for (final entry in files.entries)
        if (_parentOf(entry.key) == prefix)
          RemoteFile(name: entry.key.split('/').last, size: entry.value.length),
    ];
  }

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    final normalized = _normalize(path);
    final parent = _parentOf(normalized);
    if (parent.isNotEmpty && !folders.contains(parent)) {
      throw StorageNotFoundException(parent);
    }
    files[normalized] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> download(String path) async {
    final bytes = files[_normalize(path)];
    if (bytes == null) throw StorageNotFoundException(path);
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String path) async => files.remove(_normalize(path));

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  static String _normalize(String path) => _segments(path).join('/');

  static String _parentOf(String path) {
    final parts = _segments(path);
    return parts.isEmpty ? '' : parts.sublist(0, parts.length - 1).join('/');
  }
}
