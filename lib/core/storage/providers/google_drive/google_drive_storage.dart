import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../auth/bearer_request.dart';
import '../../../auth/oauth_token_manager.dart';
import '../../cloud_storage.dart';

/// Google Drive через REST API v3 с правом `drive.file`: приложение видит
/// только созданные им файлы.
///
/// Путей в Drive нет — файлы и папки адресуются по id, родитель задаётся
/// id. Корень наших путей — видимая папка [rootFolderName] в «Моём диске»;
/// id папок и файлов кешируются по пути.
class GoogleDriveStorage implements CloudStorage {
  GoogleDriveStorage({required this._tokens, required this._client});

  static const String rootFolderName = 'Transmitter';
  static const String _folderMime = 'application/vnd.google-apps.folder';
  static const String _api = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApi = 'https://www.googleapis.com/upload/drive/v3';

  /// До этого размера файл загружается одним multipart-запросом, больше —
  /// возобновляемой загрузкой (так рекомендует Google).
  static const int multipartLimit = 5 * 1024 * 1024;

  final OAuthTokenManager _tokens;
  final http.Client _client;
  final Map<String, String> _folderIds = {};
  final Map<String, String> _fileIds = {};

  @override
  Future<void> ensureFolder(String path) => _folderId(path, create: true);

  @override
  Future<List<RemoteFile>> listFiles(String folder) async {
    final folderPath = _normalize(folder);
    final folderId = await _folderId(folderPath, create: false);
    if (folderId == null) return [];
    final result = <RemoteFile>[];
    String? pageToken;
    do {
      final page = await _getJson('/files', {
        'q':
            "'$folderId' in parents and mimeType != '$_folderMime' and trashed = false",
        'fields': 'nextPageToken,files(id,name,size)',
        'pageSize': '1000',
        'spaces': 'drive',
        'pageToken': ?pageToken,
      });
      for (final file in (page['files'] as List).cast<Map<String, dynamic>>()) {
        final name = file['name'] as String;
        _fileIds[_join(folderPath, name)] = file['id'] as String;
        result.add(
          RemoteFile(
            name: name,
            size: int.tryParse('${file['size'] ?? 0}') ?? 0,
          ),
        );
      }
      pageToken = page['nextPageToken'] as String?;
    } while (pageToken != null);
    return result;
  }

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    final normalized = _normalize(path);
    final (parentPath, name) = _split(normalized);
    final parentId = (await _folderId(parentPath, create: true))!;
    final existingId = await _fileId(normalized);

    final String id;
    if (bytes.length <= multipartLimit) {
      id = await _uploadMultipart(
        name: name,
        parentId: parentId,
        existingId: existingId,
        bytes: bytes,
      );
    } else {
      id = await _uploadResumable(
        name: name,
        parentId: parentId,
        existingId: existingId,
        bytes: bytes,
      );
    }
    _fileIds[normalized] = id;
  }

  @override
  Future<Uint8List> download(String path) async {
    final normalized = _normalize(path);
    final id = await _fileId(normalized);
    if (id == null) throw StorageNotFoundException(path);
    final response = await _send(
      (token) => _client.get(
        Uri.parse('$_api/files/$id?alt=media'),
        headers: _auth(token),
      ),
    );
    if (response.statusCode == 404) {
      _fileIds.remove(normalized);
      throw StorageNotFoundException(path);
    }
    if (response.statusCode != 200) _fail(response);
    return response.bodyBytes;
  }

  @override
  Future<void> delete(String path) async {
    final normalized = _normalize(path);
    final id = await _fileId(normalized);
    if (id == null) return;
    final response = await _send(
      (token) =>
          _client.delete(Uri.parse('$_api/files/$id'), headers: _auth(token)),
    );
    _fileIds.remove(normalized);
    if (response.statusCode == 204 ||
        response.statusCode == 200 ||
        response.statusCode == 404) {
      return;
    }
    _fail(response);
  }

  // ---- Папки и файлы по путям ----

  /// id папки по пути (`''` — корневая папка Transmitter). При [create]
  /// недостающие папки создаются; иначе `null`, если папки нет.
  Future<String?> _folderId(String path, {required bool create}) async {
    final normalized = _normalize(path);
    final cached = _folderIds[normalized];
    if (cached != null) return cached;

    final String? parentId;
    final String name;
    if (normalized.isEmpty) {
      parentId = 'root';
      name = rootFolderName;
    } else {
      final (parentPath, last) = _split(normalized);
      parentId = await _folderId(parentPath, create: create);
      if (parentId == null) return null;
      name = last;
    }

    var id = await _findChild(parentId, name, folder: true);
    if (id == null) {
      if (!create) return null;
      id = await _createFolder(parentId, name);
    }
    return _folderIds[normalized] = id;
  }

  Future<String?> _fileId(String path) async {
    final cached = _fileIds[path];
    if (cached != null) return cached;
    final (parentPath, name) = _split(path);
    final parentId = await _folderId(parentPath, create: false);
    if (parentId == null) return null;
    final id = await _findChild(parentId, name, folder: false);
    if (id != null) _fileIds[path] = id;
    return id;
  }

  /// Ищет дочерний объект по имени. Если два устройства одновременно создали
  /// одноимённые папки, всегда берём самую раннюю — одинаково везде.
  Future<String?> _findChild(
    String parentId,
    String name, {
    required bool folder,
  }) async {
    final mimeCondition = folder
        ? "mimeType = '$_folderMime'"
        : "mimeType != '$_folderMime'";
    final json = await _getJson('/files', {
      'q':
          "name = '${_escape(name)}' and '$parentId' in parents and $mimeCondition and trashed = false",
      'fields': 'files(id)',
      'orderBy': 'createdTime',
      'pageSize': '1',
      'spaces': 'drive',
    });
    final files = json['files'] as List;
    return files.isEmpty ? null : (files.first as Map)['id'] as String;
  }

  Future<String> _createFolder(String parentId, String name) async {
    final response = await _send(
      (token) => _client.post(
        Uri.parse('$_api/files?fields=id'),
        headers: {..._auth(token), 'Content-Type': 'application/json'},
        body: utf8.encode(
          jsonEncode({
            'name': name,
            'mimeType': _folderMime,
            'parents': [parentId],
          }),
        ),
      ),
    );
    if (response.statusCode != 200) _fail(response);
    return (jsonDecode(response.body) as Map)['id'] as String;
  }

  // ---- Загрузка ----

  Future<String> _uploadMultipart({
    required String name,
    required String parentId,
    required String? existingId,
    required Uint8List bytes,
  }) async {
    const boundary = 'transmitter-boundary-7c1f';
    final metadata = existingId == null
        ? {
            'name': name,
            'parents': [parentId],
          }
        : <String, Object>{};
    final body = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n',
        ),
      )
      ..add(utf8.encode(jsonEncode(metadata)))
      ..add(
        utf8.encode(
          '\r\n--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final payload = body.takeBytes();

    final uri = existingId == null
        ? Uri.parse('$_uploadApi/files?uploadType=multipart&fields=id')
        : Uri.parse(
            '$_uploadApi/files/$existingId?uploadType=multipart&fields=id',
          );
    final response = await _send((token) {
      final headers = {
        ..._auth(token),
        'Content-Type': 'multipart/related; boundary=$boundary',
      };
      return existingId == null
          ? _client.post(uri, headers: headers, body: payload)
          : _client.patch(uri, headers: headers, body: payload);
    });
    if (response.statusCode != 200) _fail(response);
    return (jsonDecode(response.body) as Map)['id'] as String;
  }

  Future<String> _uploadResumable({
    required String name,
    required String parentId,
    required String? existingId,
    required Uint8List bytes,
  }) async {
    final metadata = existingId == null
        ? {
            'name': name,
            'parents': [parentId],
          }
        : <String, Object>{};
    final startUri = existingId == null
        ? Uri.parse('$_uploadApi/files?uploadType=resumable&fields=id')
        : Uri.parse(
            '$_uploadApi/files/$existingId?uploadType=resumable&fields=id',
          );
    final start = await _send((token) {
      final headers = {
        ..._auth(token),
        'Content-Type': 'application/json',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': '${bytes.length}',
      };
      final body = utf8.encode(jsonEncode(metadata));
      return existingId == null
          ? _client.post(startUri, headers: headers, body: body)
          : _client.patch(startUri, headers: headers, body: body);
    });
    if (start.statusCode != 200) _fail(start);
    final location = start.headers['location'];
    if (location == null) {
      throw const StorageException(
        'Google Drive не вернул адрес для загрузки файла',
      );
    }
    // Адрес сессии загрузки сам служит разрешением — токен не нужен.
    final response = await _client.put(
      Uri.parse(location),
      headers: {'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      _fail(response);
    }
    return (jsonDecode(response.body) as Map)['id'] as String;
  }

  // ---- HTTP ----

  Future<Map<String, dynamic>> _getJson(
    String endpoint,
    Map<String, String> query,
  ) async {
    final response = await _send(
      (token) => _client.get(
        Uri.parse('$_api$endpoint').replace(queryParameters: query),
        headers: _auth(token),
      ),
    );
    if (response.statusCode != 200) _fail(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
  ) => sendWithBearer(_tokens, request);

  static Map<String, String> _auth(String token) => {
    'Authorization': 'Bearer $token',
  };

  static String _normalize(String path) =>
      path.split('/').where((s) => s.isNotEmpty).join('/');

  static String _join(String folder, String name) =>
      folder.isEmpty ? name : '$folder/$name';

  static (String, String) _split(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? ('', path) : (path.substring(0, i), path.substring(i + 1));
  }

  /// Экранирование для строки в запросе Drive (`q`).
  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  static Never _fail(http.Response response) {
    var reason = '';
    var message = '';
    try {
      final error = (jsonDecode(response.body) as Map)['error'] as Map;
      message = (error['message'] ?? '').toString();
      final errors = error['errors'] as List?;
      if (errors != null && errors.isNotEmpty) {
        reason = ((errors.first as Map)['reason'] ?? '').toString();
      }
    } catch (_) {
      message = response.body.trim();
    }
    if (response.statusCode == 401) throw const StorageAuthException();
    if (reason == 'storageQuotaExceeded' || reason == 'quotaExceeded') {
      throw const StorageQuotaException();
    }
    if (reason.contains('rateLimit') || response.statusCode == 429) {
      throw const StorageException(
        'Google Drive временно ограничил запросы, попробуйте позже',
      );
    }
    if (message.length > 300) message = '${message.substring(0, 300)}…';
    throw StorageException(
      'Ошибка Google Drive (${response.statusCode})${message.isEmpty ? '' : ': $message'}',
    );
  }
}
