import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../errors/app_error.dart';
import '../../cloud_provider_id.dart';
import '../../cloud_storage.dart';
import '../../public_sharing.dart';

/// Скачивание открытых по ссылке файлов Google Drive без входа — по id
/// файла и API-ключу приложения (не секретному, только для Drive API).
/// Чтение из браузера (CORS) Google разрешает.
class GooglePublicReader implements PublicFileReader {
  const GooglePublicReader({required this._client, required this._apiKey});

  final http.Client _client;
  final String _apiKey;

  @override
  CloudProviderId get provider => CloudProviderId.googleDrive;

  @override
  Future<Uint8List> download(String locator) async {
    final response = await _client.get(
      Uri.https('www.googleapis.com', '/drive/v3/files/$locator', {
        'alt': 'media',
        'key': _apiKey,
      }),
    );
    if (response.statusCode == 200) return response.bodyBytes;
    if (response.statusCode == 429) {
      throw const StorageException(ErrorCode.cloudRateLimited, {
        'provider': 'Google Drive',
      });
    }
    // Доступ закрыли (Drive отвечает 404) или файл удалили.
    if (response.statusCode == 404 || response.statusCode == 403) {
      throw StorageNotFoundException(locator);
    }
    throw StorageException.request('Google Drive', '${response.statusCode}');
  }
}
