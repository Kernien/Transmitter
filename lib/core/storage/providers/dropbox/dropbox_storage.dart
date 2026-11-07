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

/// Dropbox через HTTP API v2. Приложение с доступом «App folder», поэтому
/// корень путей — папка `Приложения/<имя приложения>` в Dropbox пользователя.
///
/// Публичные ссылки (для досок) требуют права `sharing.write`; у входа,
/// сделанного до его появления, права нет — нужен новый вход.
class DropboxStorage implements CloudStorage, PublicSharing {
  DropboxStorage({
    required this._tokens,
    required this._client,
    @visibleForTesting this.uploadChunkSize = defaultUploadChunkSize,
    @visibleForTesting this.retryDelay = const Duration(seconds: 1),
  });

  static const String _rpcHost = 'https://api.dropboxapi.com/2';
  static const String _contentHost = 'https://content.dropboxapi.com/2';

  /// Размер одного куска в сеансе загрузки Dropbox (8 МБ, кратно 4 МБ).
  static const int defaultUploadChunkSize = 8 * 1024 * 1024;

  final OAuthTokenManager _tokens;
  final http.Client _client;
  final int uploadChunkSize;
  final Duration retryDelay;

  @override
  Future<void> ensureFolder(String path) async {
    final remote = _remote(path);
    if (remote.isEmpty) return;
    // Dropbox сам создаёт недостающие родительские папки.
    final response = await _rpc('/files/create_folder_v2', {
      'path': remote,
      'autorename': false,
    });
    if (response.statusCode == 200) return;
    if (_errorSummary(response).startsWith('path/conflict')) return;
    _fail(response);
  }

  @override
  Future<List<RemoteFile>> listFiles(String folder) async {
    var response = await _rpc('/files/list_folder', {
      'path': _remote(folder),
      'limit': 2000,
    });
    if (response.statusCode == 409 &&
        _errorSummary(response).contains('not_found')) {
      return [];
    }
    final result = <RemoteFile>[];
    while (true) {
      if (response.statusCode != 200) _fail(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      for (final entry
          in (json['entries'] as List).cast<Map<String, dynamic>>()) {
        if (entry['.tag'] == 'file') {
          result.add(
            RemoteFile(
              name: entry['name'] as String,
              size: (entry['size'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
      if (json['has_more'] != true) return result;
      response = await _rpc('/files/list_folder/continue', {
        'cursor': json['cursor'],
      });
    }
  }

  @override
  Future<void> upload(
    String path,
    Uint8List bytes, {
    ProgressCallback? onProgress,
  }) async {
    if (bytes.length > uploadChunkSize) {
      return uploadStream(
        path,
        Stream.value(bytes),
        length: bytes.length,
        onProgress: onProgress,
      );
    }
    onProgress?.call(0, bytes.length);
    final response = await _contentWithRetry('/files/upload', {
      'path': _remote(path),
      'mode': 'overwrite',
      'mute': true,
    }, body: bytes);
    if (response.statusCode != 200) _fail(response);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> uploadStream(
    String path,
    Stream<List<int>> stream, {
    required int length,
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, length);
    final commit = {
      'path': _remote(path),
      'mode': 'overwrite',
      'mute': true,
    };
    final buffer = BytesBuilder(copy: false);
    final chunks = <Uint8List>[];
    String? sessionId;
    var offset = 0;

    Future<void> sendSessionChunk(Uint8List chunk, {required bool isLast}) async {
      if (sessionId == null) {
        if (isLast) {
          final response = await _contentWithRetry(
            '/files/upload',
            commit,
            body: chunk,
          );
          if (response.statusCode != 200) _fail(response);
          offset += chunk.length;
          onProgress?.call(offset, length);
          return;
        }
        final start = await _contentWithRetry(
          '/files/upload_session/start',
          {'close': false},
          body: chunk,
        );
        if (start.statusCode != 200) _fail(start);
        sessionId =
            (jsonDecode(start.body) as Map<String, dynamic>)['session_id']
                as String;
        offset += chunk.length;
        onProgress?.call(offset, length);
        return;
      }
      final cursor = {'session_id': sessionId, 'offset': offset};
      if (isLast) {
        final finish = await _contentWithRetry(
          '/files/upload_session/finish',
          {'cursor': cursor, 'commit': commit},
          body: chunk,
        );
        if (finish.statusCode != 200) _fail(finish);
      } else {
        final append = await _contentWithRetry(
          '/files/upload_session/append_v2',
          {'cursor': cursor, 'close': false},
          body: chunk,
        );
        if (append.statusCode != 200) _fail(append);
      }
      offset += chunk.length;
      onProgress?.call(offset, length);
    }

    await for (final piece in stream) {
      if (piece.isEmpty) continue;
      buffer.add(piece);
      while (buffer.length >= uploadChunkSize) {
        final all = buffer.takeBytes();
        var pos = 0;
        while (all.length - pos >= uploadChunkSize) {
          final slice = Uint8List.sublistView(all, pos, pos + uploadChunkSize);
          pos += uploadChunkSize;
          if (chunks.isNotEmpty) {
            await sendSessionChunk(chunks.removeAt(0), isLast: false);
          }
          chunks.add(slice);
        }
        if (pos < all.length) {
          buffer.add(Uint8List.sublistView(all, pos));
        }
      }
    }

    final tail = buffer.takeBytes();
    if (tail.isNotEmpty) {
      if (chunks.isNotEmpty) {
        await sendSessionChunk(chunks.removeAt(0), isLast: false);
      }
      await sendSessionChunk(tail, isLast: true);
    } else if (chunks.isNotEmpty) {
      await sendSessionChunk(chunks.removeAt(0), isLast: true);
    } else {
      await sendSessionChunk(Uint8List(0), isLast: true);
    }
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
    final response = await _contentStream('/files/download', {
      'path': _remote(path),
    });
    if (response.statusCode == 409) {
      final body = await response.stream.bytesToString();
      if (_summaryFromBody(body).contains('not_found')) {
        throw StorageNotFoundException(path);
      }
      _failFromBody(response.statusCode, body);
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
    final response = await _rpc('/files/delete_v2', {'path': _remote(path)});
    if (response.statusCode == 200) return;
    if (response.statusCode == 409 &&
        _errorSummary(response).contains('not_found')) {
      return;
    }
    _fail(response);
  }

  @override
  Future<List<String>> listFolders(String folder) async {
    var response = await _rpc('/files/list_folder', {
      'path': _remote(folder),
      'limit': 2000,
    });
    if (response.statusCode == 409 &&
        _errorSummary(response).contains('not_found')) {
      return [];
    }
    final result = <String>[];
    while (true) {
      if (response.statusCode != 200) _fail(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      for (final entry
          in (json['entries'] as List).cast<Map<String, dynamic>>()) {
        if (entry['.tag'] == 'folder') {
          result.add(entry['name'] as String);
        }
      }
      if (json['has_more'] != true) return result;
      response = await _rpc('/files/list_folder/continue', {
        'cursor': json['cursor'],
      });
    }
  }

  @override
  Future<void> renameFolder(String fromPath, String toPath) async {
    final from = _remote(fromPath);
    final to = _remote(toPath);
    if (from.isEmpty || to.isEmpty || from == to) return;
    final response = await _rpc('/files/move_v2', {
      'from_path': from,
      'to_path': to,
      'autorename': false,
    });
    if (response.statusCode == 200) return;
    final summary = _errorSummary(response);
    if (response.statusCode == 409 &&
        (summary.contains('not_found') || summary.contains('conflict'))) {
      return;
    }
    _fail(response);
  }

  // ---- Публичные ссылки ----

  /// Локатор — ссылка вида `https://www.dropbox.com/scl/fi/…?rlkey=…`;
  /// [DropboxPublicReader] скачивает по ней файл напрямую.
  @override
  Future<String> publish(String path) async {
    final remote = _remote(path);
    final response = await _rpc('/sharing/create_shared_link_with_settings', {
      'path': remote,
    });
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as Map)['url'] as String;
    }
    final summary = _errorSummary(response);
    if (summary.startsWith('shared_link_already_exists')) {
      final listed = await _rpc('/sharing/list_shared_links', {
        'path': remote,
        'direct_only': true,
      });
      if (listed.statusCode != 200) _fail(listed);
      final links = (jsonDecode(listed.body) as Map)['links'] as List;
      if (links.isNotEmpty) return (links.first as Map)['url'] as String;
    }
    if (summary.contains('not_found')) throw StorageNotFoundException(path);
    _fail(response);
  }

  @override
  Future<void> unpublish(String path, String locator) async {
    final response = await _rpc('/sharing/revoke_shared_link', {
      'url': locator,
    });
    // 409 — ссылки уже нет.
    if (response.statusCode == 200 || response.statusCode == 409) return;
    _fail(response);
  }

  Future<http.Response> _rpc(String endpoint, Map<String, Object?> args) =>
      _authorized(
        (token) => _client.post(
          Uri.parse('$_rpcHost$endpoint'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          // Тело передаётся байтами: для строки пакет http дописал бы
          // «; charset=utf-8» к Content-Type, а Dropbox отвечает на это 400.
          body: utf8.encode(jsonEncode(args)),
        ),
      );

  Future<http.Response> _contentWithRetry(
    String endpoint,
    Map<String, Object?> arg, {
    Uint8List? body,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _content(endpoint, arg, body: body);
        if ((response.statusCode == 500 ||
                response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504) &&
            attempt < 2) {
          await Future<void>.delayed(retryDelay * pow(2, attempt));
          continue;
        }
        return response;
      } on http.ClientException {
        if (attempt >= 2) rethrow;
        await Future<void>.delayed(retryDelay * pow(2, attempt));
      }
    }
  }

  Future<http.Response> _content(
    String endpoint,
    Map<String, Object?> arg, {
    Uint8List? body,
  }) => _authorized(
    (token) => _client.post(
      Uri.parse('$_contentHost$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Dropbox-API-Arg': _headerJson(arg),
        if (body != null) 'Content-Type': 'application/octet-stream',
      },
      body: body,
    ),
  );

  Future<http.StreamedResponse> _contentStream(
    String endpoint,
    Map<String, Object?> arg,
  ) => sendWithBearerStream(
    _tokens,
    (token) => _client.send(
      http.Request('POST', Uri.parse('$_contentHost$endpoint'))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Dropbox-API-Arg'] = _headerJson(arg),
    ),
  );

  Future<http.Response> _authorized(
    Future<http.Response> Function(String token) request,
  ) => sendWithBearer(_tokens, request);

  /// Путь в формате Dropbox: корень — пустая строка, остальное с ведущим `/`.
  static String _remote(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty);
    return segments.isEmpty ? '' : '/${segments.join('/')}';
  }

  /// Заголовок Dropbox-API-Arg должен быть в ASCII: остальные символы
  /// экранируются как \uXXXX.
  static String _headerJson(Map<String, Object?> arg) => jsonEncode(arg)
      .replaceAllMapped(
        RegExp(r'[^\x00-\x7F]'),
        (m) => '\\u${m[0]!.codeUnitAt(0).toRadixString(16).padLeft(4, '0')}',
      );

  static String _summaryFromBody(String body) {
    try {
      return ((jsonDecode(body) as Map)['error_summary'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _errorSummary(http.Response response) =>
      _summaryFromBody(response.body);

  static Never _fail(http.Response response) =>
      _failFromBody(response.statusCode, response.body);

  static Never _failFromBody(int statusCode, String body) {
    var summary = _summaryFromBody(body);
    // Ошибки формата запроса (400) Dropbox присылает обычным текстом.
    if (summary.isEmpty) summary = body.trim();
    if (summary.length > 300) summary = '${summary.substring(0, 300)}…';
    if (summary.contains('missing_scope')) {
      throw const StorageException(ErrorCode.cloudSharingNotAllowed, {
        'provider': 'Dropbox',
      });
    }
    if (statusCode == 401) throw const StorageAuthException();
    if (summary.contains('insufficient_space')) {
      throw const StorageQuotaException();
    }
    if (statusCode == 429) {
      throw const StorageException(ErrorCode.cloudRateLimited, {
        'provider': 'Dropbox',
      });
    }
    throw StorageException.request(
      'Dropbox',
      summary.isEmpty ? '$statusCode' : '$statusCode: $summary',
    );
  }
}
