import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../cloud_storage.dart';

/// Хранилище P2P-доски на локальном диске устройства.
///
/// Реализует [CloudStorage] поверх локальной файловой системы, сохраняя
/// посты и файлы в заданной директории [baseDirectory].
class IoP2pStorage implements CloudStorage {
  IoP2pStorage(this.baseDirectory);

  final Directory baseDirectory;

  String _cleanPath(String path) {
    var p = path.replaceAll('\\', '/');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  File _file(String path) => File('${baseDirectory.path}/${_cleanPath(path)}');
  Directory _dir(String path) =>
      Directory('${baseDirectory.path}/${_cleanPath(path)}');

  @override
  Future<void> ensureFolder(String path) async {
    final d = _dir(path);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
  }

  @override
  Future<List<RemoteFile>> listFiles(String folder) async {
    final d = _dir(folder);
    if (!await d.exists()) return const [];
    final result = <RemoteFile>[];
    await for (final entity in d.list(followLinks: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        result.add(RemoteFile(name: name, size: stat.size));
      }
    }
    return result;
  }

  @override
  Future<void> upload(
    String path,
    Uint8List bytes, {
    ProgressCallback? onProgress,
  }) async {
    final target = _file(path);
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> uploadStream(
    String path,
    Stream<List<int>> stream, {
    required int length,
    ProgressCallback? onProgress,
  }) async {
    final target = _file(path);
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    final sink = temp.openWrite();
    var sent = 0;
    onProgress?.call(0, length);
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent, length);
      }
      await sink.flush();
      await sink.close();
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
    } catch (_) {
      await sink.close();
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> download(String path, {ProgressCallback? onProgress}) async {
    final target = _file(path);
    if (!await target.exists()) {
      throw StorageNotFoundException(path);
    }
    final bytes = await target.readAsBytes();
    onProgress?.call(bytes.length, bytes.length);
    return bytes;
  }

  @override
  Stream<Uint8List> downloadStream(
    String path, {
    ProgressCallback? onProgress,
  }) async* {
    final target = _file(path);
    if (!await target.exists()) {
      throw StorageNotFoundException(path);
    }
    final length = await target.length();
    var sent = 0;
    onProgress?.call(0, length);
    await for (final chunk in target.openRead()) {
      sent += chunk.length;
      onProgress?.call(sent, length);
      yield Uint8List.fromList(chunk);
    }
  }

  @override
  Future<void> delete(String path) async {
    final fileTarget = _file(path);
    if (await fileTarget.exists()) {
      await fileTarget.delete();
      return;
    }
    final dirTarget = _dir(path);
    if (await dirTarget.exists()) {
      await dirTarget.delete(recursive: true);
    }
  }

  @override
  Future<List<String>> listFolders(String folder) async {
    final d = _dir(folder);
    if (!await d.exists()) return const [];
    final result = <String>[];
    await for (final entity in d.list(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        result.add(name);
      }
    }
    return result;
  }

  @override
  Future<void> renameFolder(String fromPath, String toPath) async {
    final from = _dir(fromPath);
    if (!await from.exists()) return;
    final to = _dir(toPath);
    if (from.path == to.path) return;
    await to.parent.create(recursive: true);
    await from.rename(to.path);
  }
}

Future<CloudStorage> createPlatformP2pStorage() async {
  try {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/p2p_vaults');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return IoP2pStorage(dir);
  } catch (e) {
    debugPrint('P2P local disk storage unavailable: $e');
    final temp = Directory.systemTemp.createTempSync('transmitter_p2p_');
    return IoP2pStorage(temp);
  }
}
