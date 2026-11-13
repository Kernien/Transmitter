import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../auth/bearer_request.dart';
import '../../../auth/oauth_token_manager.dart';
import '../../../errors/app_error.dart';
import '../../cloud_storage.dart';
import '../../public_sharing.dart';

/// Google Drive через REST API v3 с правом `drive.file`: приложение видит
/// только созданные им файлы.
///
/// Путей в Drive нет — файлы и папки адресуются по id, родитель задаётся
/// id. Корень наших путей — видимая папка [rootFolderName] в «Моём диске»;
/// id папок и файлов кешируются по пути.
///
/// Публичный доступ (для досок) — разрешение «все, у кого есть ссылка» на
/// файл; `drive.file` позволяет это для файлов приложения.
class GoogleDriveStorage implements CloudStorage, PublicSharing {
  GoogleDriveStorage({
    required this._tokens,
    required this._client,
    @visibleForTesting this.resumableChunkSize = defaultResumableChunkSize,
    @visibleForTesting this.retryDelay = const Duration(seconds: 1),
  });

  static const String rootFolderName = 'Transmitter';
  static const String _folderMime = 'application/vnd.google-apps.folder';
  static const String _api = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApi = 'https://www.googleapis.com/upload/drive/v3';

  /// До этого размера файл загружается одним multipart-запросом, больше —
  /// возобновляемой загрузкой (так рекомендует Google).
  static const int multipartLimit = 5 * 1024 * 1024;

  /// Размер одного куска при возобновляемой загрузке (8 МБ, кратно 256 КБ).
  static const int defaultResumableChunkSize = 8 * 1024 * 1024;

  final OAuthTokenManager _tokens;
  final http.Client _client;
  final int resumableChunkSize;
  final Duration retryDelay;
  final Map<String, String> _folderIds = {};
  final Map<String, Future<String?>> _folderIdInFlight = {};
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
  Future<void> upload(
    String path,
    Uint8List bytes, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, bytes.length);
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
      onProgress?.call(bytes.length, bytes.length);
    } else {
      id = await _uploadResumableStream(
        name: name,
        parentId: parentId,
        existingId: existingId,
        stream: Stream.value(bytes),
        length: bytes.length,
        onProgress: onProgress,
      );
    }
    _fileIds[normalized] = id;
  }

  @override
  Future<void> uploadStream(
    String path,
    Stream<List<int>> stream, {
    required int length,
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, length);
    if (length <= multipartLimit) {
      final b = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        b.add(chunk);
      }
      return upload(path, b.takeBytes(), onProgress: onProgress);
    }
    final normalized = _normalize(path);
    final (parentPath, name) = _split(normalized);
    final parentId = (await _folderId(parentPath, create: true))!;
    final existingId = await _fileId(normalized);
    final id = await _uploadResumableStream(
      name: name,
      parentId: parentId,
      existingId: existingId,
      stream: stream,
      length: length,
      onProgress: onProgress,
    );
    _fileIds[normalized] = id;
  }

  @override
  Future<Uint8List> download(String path, {ProgressCallback? onProgress}) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in downloadStream(path, onProgress: onProgress)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  Stream<Uint8List> downloadStream(
    String path, {
    ProgressCallback? onProgress,
  }) async* {
    final normalized = _normalize(path);
    final id = await _fileId(normalized);
    if (id == null) throw StorageNotFoundException(path);
    final response = await _sendStream(
      (token) => _client.send(
        http.Request('GET', Uri.parse('$_api/files/$id?alt=media'))
          ..headers.addAll(_auth(token)),
      ),
    );
    if (response.statusCode == 404) {
      _fileIds.remove(normalized);
      throw StorageNotFoundException(path);
    }
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      _failFromBody(response.statusCode, body);
    }
    final total = response.contentLength ?? 0;
    var received = 0;
    await for (final chunk in response.stream) {
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      received += bytes.length;
      onProgress?.call(received, total);
      yield bytes;
    }
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

  @override
  Future<List<String>> listFolders(String folder) async {
    final folderPath = _normalize(folder);
    final folderId = await _folderId(folderPath, create: false);
    if (folderId == null) return [];
    final result = <String>[];
    String? pageToken;
    do {
      final page = await _getJson('/files', {
        'q':
            "'$folderId' in parents and mimeType = '$_folderMime' and trashed = false",
        'fields': 'nextPageToken,files(id,name)',
        'pageSize': '1000',
        'spaces': 'drive',
        'pageToken': ?pageToken,
      });
      for (final item in (page['files'] as List).cast<Map<String, dynamic>>()) {
        final name = item['name'] as String;
        _folderIds[_join(folderPath, name)] = item['id'] as String;
        result.add(name);
      }
      pageToken = page['nextPageToken'] as String?;
    } while (pageToken != null);
    return result;
  }

  @override
  Future<void> renameFolder(String fromPath, String toPath) async {
    final from = _normalize(fromPath);
    final to = _normalize(toPath);
    if (from.isEmpty || to.isEmpty || from == to) return;
    final (_, newName) = _split(to);
    final id = await _folderId(from, create: false);
    if (id == null) return;
    final response = await _send(
      (token) => _client.patch(
        Uri.parse('$_api/files/$id?fields=id'),
        headers: {..._auth(token), 'Content-Type': 'application/json'},
        body: utf8.encode(jsonEncode({'name': newName})),
      ),
    );
    if (response.statusCode == 404) {
      _evictPrefix(from);
      return;
    }
    if (response.statusCode != 200) _fail(response);
    _evictPrefix(from);
    _folderIds[to] = id;
  }

  void _evictPrefix(String prefix) {
    _folderIds.removeWhere((k, _) => k == prefix || k.startsWith('$prefix/'));
    _fileIds.removeWhere((k, _) => k == prefix || k.startsWith('$prefix/'));
  }

  // ---- Публичный доступ ----

  /// Id разрешения «все, у кого есть ссылка» в Drive.
  static const String _anyonePermission = 'anyoneWithLink';

  /// Локатор — id файла; [GooglePublicReader] скачивает его с API-ключом.
  @override
  Future<String> publish(String path) async {
    final normalized = _normalize(path);
    final id = await _fileId(normalized);
    if (id == null) throw StorageNotFoundException(path);
    final response = await _send(
      (token) => _client.post(
        Uri.parse('$_api/files/$id/permissions?fields=id'),
        headers: {..._auth(token), 'Content-Type': 'application/json'},
        body: utf8.encode(jsonEncode({'role': 'reader', 'type': 'anyone'})),
      ),
    );
    if (response.statusCode == 404) {
      _fileIds.remove(normalized);
      throw StorageNotFoundException(path);
    }
    if (response.statusCode != 200) _fail(response);
    return id;
  }

  @override
  Future<void> unpublish(String path, String locator) async {
    final response = await _send(
      (token) => _client.delete(
        Uri.parse('$_api/files/$locator/permissions/$_anyonePermission'),
        headers: _auth(token),
      ),
    );
    // 404 — файла или разрешения уже нет.
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
  Future<String?> _folderId(String path, {required bool create}) {
    final normalized = _normalize(path);
    final cached = _folderIds[normalized];
    if (cached != null) return Future.value(cached);
    if (!create) return _resolveFolderId(normalized, create: false);
    final inFlight = _folderIdInFlight[normalized];
    if (inFlight != null) return inFlight;
    final future = _resolveFolderId(normalized, create: true).whenComplete(() {
      _folderIdInFlight.remove(normalized);
    });
    return _folderIdInFlight[normalized] = future;
  }

  Future<String?> _resolveFolderId(String normalized, {required bool create}) async {
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

  Future<String> _uploadResumableStream({
    required String name,
    required String parentId,
    required String? existingId,
    required Stream<List<int>> stream,
    required int length,
    ProgressCallback? onProgress,
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
        'X-Upload-Content-Length': '$length',
      };
      final body = utf8.encode(jsonEncode(metadata));
      return existingId == null
          ? _client.post(startUri, headers: headers, body: body)
          : _client.patch(startUri, headers: headers, body: body);
    });
    if (start.statusCode != 200) _fail(start);
    final location = start.headers['location'];
    if (location == null) {
      throw const StorageException(ErrorCode.cloudNoUploadUrl, {
        'provider': 'Google Drive',
      });
    }
    final sessionUri = Uri.parse(location);
    if (length == 0) {
      final response = await _putChunkWithRetry(sessionUri, Uint8List(0), 0, 0);
      onProgress?.call(0, 0);
      return (jsonDecode(response.body) as Map)['id'] as String;
    }

    final buffer = BytesBuilder(copy: false);
    var offset = 0;
    http.Response? lastResponse;

    Future<void> flushChunk(Uint8List chunk) async {
      lastResponse = await _putChunkWithRetry(
        sessionUri,
        chunk,
        offset,
        length,
      );
      offset += chunk.length;
      onProgress?.call(offset, length);
    }

    await for (final piece in stream) {
      if (piece.isEmpty) continue;
      buffer.add(piece);
      while (buffer.length >= resumableChunkSize) {
        final all = buffer.takeBytes();
        var pos = 0;
        while (all.length - pos >= resumableChunkSize) {
          await flushChunk(
            Uint8List.sublistView(all, pos, pos + resumableChunkSize),
          );
          pos += resumableChunkSize;
        }
        if (pos < all.length) {
          buffer.add(Uint8List.sublistView(all, pos));
        }
      }
    }

    final tail = buffer.takeBytes();
    if (tail.isNotEmpty) {
      await flushChunk(tail);
    }
    final response = lastResponse;
    if (response == null ||
        (response.statusCode != 200 && response.statusCode != 201)) {
      throw StorageException.request(
        'Google Drive',
        'resumable upload incomplete',
      );
    }
    return (jsonDecode(response.body) as Map)['id'] as String;
  }

  /// Отправляет один кусок в сеансе возобновляемой загрузки Drive с повтором
  /// при временных сбоях сети или ответах 5xx.
  Future<http.Response> _putChunkWithRetry(
    Uri sessionUri,
    Uint8List chunk,
    int offset,
    int totalLength,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/octet-stream',
      if (totalLength > 0)
        'Content-Range':
            'bytes $offset-${offset + chunk.length - 1}/$totalLength',
    };
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _client.put(
          sessionUri,
          headers: headers,
          body: chunk,
        );
        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 308) {
          return response;
        }
        if ((response.statusCode == 500 ||
                response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504) &&
            attempt < 2) {
          await Future<void>.delayed(retryDelay * pow(2, attempt));
          continue;
        }
        _fail(response);
      } on http.ClientException {
        if (attempt >= 2) rethrow;
        await Future<void>.delayed(retryDelay * pow(2, attempt));
      }
    }
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

  Future<http.StreamedResponse> _sendStream(
    Future<http.StreamedResponse> Function(String token) request,
  ) => sendWithBearerStream(_tokens, request);

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

  static Never _fail(http.Response response) =>
      _failFromBody(response.statusCode, response.body);

  static Never _failFromBody(int statusCode, String body) {
    var reason = '';
    var message = '';
    try {
      final error = (jsonDecode(body) as Map)['error'] as Map;
      message = (error['message'] ?? '').toString();
      final errors = error['errors'] as List?;
      if (errors != null && errors.isNotEmpty) {
        reason = ((errors.first as Map)['reason'] ?? '').toString();
      }
    } catch (_) {
      message = body.trim();
    }
    if (statusCode == 401) throw const StorageAuthException();
    if (reason == 'storageQuotaExceeded' || reason == 'quotaExceeded') {
      throw const StorageQuotaException();
    }
    if (reason.contains('rateLimit') || statusCode == 429) {
      throw const StorageException(ErrorCode.cloudRateLimited, {
        'provider': 'Google Drive',
      });
    }
    if (message.length > 300) message = '${message.substring(0, 300)}…';
    throw StorageException.request(
      'Google Drive',
      message.isEmpty ? '$statusCode' : '$statusCode: $message',
    );
  }
}
