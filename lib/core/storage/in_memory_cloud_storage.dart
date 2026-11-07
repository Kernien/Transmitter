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
  Future<void> upload(
    String path,
    Uint8List bytes, {
    ProgressCallback? onProgress,
  }) async {
    final normalized = _normalize(path);
    final parent = _parentOf(normalized);
    if (parent.isNotEmpty && !folders.contains(parent)) {
      throw StorageNotFoundException(parent);
    }
    files[normalized] = Uint8List.fromList(bytes);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> uploadStream(
    String path,
    Stream<List<int>> stream, {
    required int length,
    ProgressCallback? onProgress,
  }) async {
    final builder = BytesBuilder(copy: false);
    var sent = 0;
    onProgress?.call(0, length);
    await for (final chunk in stream) {
      builder.add(chunk);
      sent += chunk.length;
      onProgress?.call(sent, length);
    }
    await upload(path, builder.takeBytes());
  }

  @override
  Future<Uint8List> download(String path, {ProgressCallback? onProgress}) async {
    final bytes = files[_normalize(path)];
    if (bytes == null) throw StorageNotFoundException(path);
    onProgress?.call(bytes.length, bytes.length);
    return Uint8List.fromList(bytes);
  }

  @override
  Stream<Uint8List> downloadStream(
    String path, {
    ProgressCallback? onProgress,
  }) async* {
    final bytes = await download(path, onProgress: onProgress);
    yield bytes;
  }

  @override
  Future<void> delete(String path) async => files.remove(_normalize(path));

  @override
  Future<List<String>> listFolders(String folder) async {
    final prefix = _normalize(folder);
    return [
      for (final f in folders)
        if (_parentOf(f) == prefix) f.split('/').last,
    ];
  }

  @override
  Future<void> renameFolder(String fromPath, String toPath) async {
    final from = _normalize(fromPath);
    final to = _normalize(toPath);
    if (from == to || !folders.contains(from)) return;
    final movedFolders = [
      for (final f in folders)
        if (f == from || f.startsWith('$from/')) f,
    ];
    for (final f in movedFolders) {
      folders
        ..remove(f)
        ..add(f == from ? to : '$to${f.substring(from.length)}');
    }
    final movedFiles = [
      for (final entry in files.entries)
        if (entry.key.startsWith('$from/')) entry,
    ];
    for (final entry in movedFiles) {
      files.remove(entry.key);
      files['$to${entry.key.substring(from.length)}'] = entry.value;
    }
  }

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  static String _normalize(String path) => _segments(path).join('/');

  static String _parentOf(String path) {
    final parts = _segments(path);
    return parts.isEmpty ? '' : parts.sublist(0, parts.length - 1).join('/');
  }
}
