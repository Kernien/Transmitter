import 'dart:typed_data';

import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/storage/public_sharing.dart';

/// Облако в памяти с публичными ссылками: локатор — `pub:<путь>`.
class SharingCloud extends InMemoryCloudStorage implements PublicSharing {
  /// Открытые по ссылке пути.
  final Set<String> published = {};
  int publishCalls = 0;
  int uploads = 0;

  static String _norm(String path) =>
      path.split('/').where((s) => s.isNotEmpty).join('/');

  @override
  Future<void> upload(String path, Uint8List bytes) {
    uploads++;
    return super.upload(path, bytes);
  }

  @override
  Future<void> delete(String path) async {
    await super.delete(path);
    // Удалённый файл больше не открыт по ссылке.
    published.remove(_norm(path));
  }

  @override
  Future<String> publish(String path) async {
    publishCalls++;
    final normalized = _norm(path);
    if (!files.containsKey(normalized)) throw StorageNotFoundException(path);
    published.add(normalized);
    return 'pub:$normalized';
  }

  @override
  Future<void> unpublish(String path, String locator) async {
    published.remove(locator.substring('pub:'.length));
  }
}

/// Читатель облака [SharingCloud] без входа.
class SharingCloudReader implements PublicFileReader {
  SharingCloudReader(this._cloud);

  final SharingCloud _cloud;

  @override
  CloudProviderId get provider => CloudProviderId.dropbox;

  @override
  Future<Uint8List> download(String locator) async {
    final path = locator.substring('pub:'.length);
    final bytes = _cloud.files[path];
    if (!_cloud.published.contains(path) || bytes == null) {
      throw StorageNotFoundException(locator);
    }
    return Uint8List.fromList(bytes);
  }
}
