import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../errors/app_error.dart';
import '../../cloud_provider_id.dart';
import '../../cloud_storage.dart';
import '../../public_sharing.dart';

/// Скачивание по публичной ссылке Dropbox без входа.
///
/// Ссылка `www.dropbox.com/scl/…?rlkey=…&dl=0` открывает страницу
/// просмотра; тот же путь на `dl.dropboxusercontent.com` (без `dl`) отдаёт
/// сам файл и разрешает чтение из браузера (CORS).
class DropboxPublicReader implements PublicFileReader {
  const DropboxPublicReader(this._client);

  final http.Client _client;

  @override
  CloudProviderId get provider => CloudProviderId.dropbox;

  /// Прямой адрес файла для ссылки [locator].
  static Uri directUrl(String locator) {
    final link = Uri.parse(locator);
    return link.replace(
      host: 'dl.dropboxusercontent.com',
      queryParameters: {
        for (final entry in link.queryParameters.entries)
          if (entry.key != 'dl') entry.key: entry.value,
      },
    );
  }

  @override
  Future<Uint8List> download(
    String locator, {
    ProgressCallback? onProgress,
  }) async {
    final response = await _client.send(
      http.Request('GET', directUrl(locator)),
    );
    if (response.statusCode == 200) {
      final total = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      return builder.takeBytes();
    }
    if (response.statusCode == 429) {
      throw const StorageException(ErrorCode.cloudRateLimited, {
        'provider': 'Dropbox',
      });
    }
    // Ссылку отозвали или файл удалили.
    if (response.statusCode >= 400 && response.statusCode < 500) {
      throw StorageNotFoundException(locator);
    }
    throw StorageException.request('Dropbox', '${response.statusCode}');
  }
}
