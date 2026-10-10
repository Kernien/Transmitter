import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../auth/oauth_token_manager.dart';
import '../../cloud_storage.dart';

/// Dropbox через HTTP API v2. Приложение с доступом «App folder», поэтому
/// корень путей — папка `Приложения/<имя приложения>` в Dropbox пользователя.
class DropboxStorage implements CloudStorage {
  DropboxStorage({required this._tokens, required this._client});

  static const String _rpcHost = 'https://api.dropboxapi.com/2';
  static const String _contentHost = 'https://content.dropboxapi.com/2';

  final OAuthTokenManager _tokens;
  final http.Client _client;

  @override
  Future<void> ensureFolder(String path) async {
    final remote = _remote(path);
    if (remote.isEmpty) return;
    // Dropbox сам создаёт недостающие родительские папки.
    final response = await _rpc('/files/create_folder_v2', {'path': remote, 'autorename': false});
    if (response.statusCode == 200) return;
    if (_errorSummary(response).startsWith('path/conflict')) return;
    _fail(response);
  }

  @override
  Future<List<RemoteFile>> listFiles(String folder) async {
    var response = await _rpc('/files/list_folder', {'path': _remote(folder), 'limit': 2000});
    if (response.statusCode == 409 && _errorSummary(response).contains('not_found')) {
      return [];
    }
    final result = <RemoteFile>[];
    while (true) {
      if (response.statusCode != 200) _fail(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      for (final entry in (json['entries'] as List).cast<Map<String, dynamic>>()) {
        if (entry['.tag'] == 'file') {
          result.add(RemoteFile(
            name: entry['name'] as String,
            size: (entry['size'] as num?)?.toInt() ?? 0,
          ));
        }
      }
      if (json['has_more'] != true) return result;
      response = await _rpc('/files/list_folder/continue', {'cursor': json['cursor']});
    }
  }

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    final response = await _content(
      '/files/upload',
      {'path': _remote(path), 'mode': 'overwrite', 'mute': true},
      body: bytes,
    );
    if (response.statusCode != 200) _fail(response);
  }

  @override
  Future<Uint8List> download(String path) async {
    final response = await _content('/files/download', {'path': _remote(path)});
    if (response.statusCode == 409 && _errorSummary(response).contains('not_found')) {
      throw StorageNotFoundException(path);
    }
    if (response.statusCode != 200) _fail(response);
    return response.bodyBytes;
  }

  @override
  Future<void> delete(String path) async {
    final response = await _rpc('/files/delete_v2', {'path': _remote(path)});
    if (response.statusCode == 200) return;
    if (response.statusCode == 409 && _errorSummary(response).contains('not_found')) return;
    _fail(response);
  }

  Future<http.Response> _rpc(String endpoint, Map<String, Object?> args) => _authorized(
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

  Future<http.Response> _content(
    String endpoint,
    Map<String, Object?> arg, {
    Uint8List? body,
  }) =>
      _authorized(
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

  /// Выполняет запрос; при ответе 401 один раз обновляет токен и повторяет.
  Future<http.Response> _authorized(
    Future<http.Response> Function(String token) request,
  ) async {
    final response = await request(await _tokens.accessToken());
    if (response.statusCode != 401) return response;
    return request(await _tokens.refresh());
  }

  /// Путь в формате Dropbox: корень — пустая строка, остальное с ведущим `/`.
  static String _remote(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty);
    return segments.isEmpty ? '' : '/${segments.join('/')}';
  }

  /// Заголовок Dropbox-API-Arg должен быть в ASCII: остальные символы
  /// экранируются как \uXXXX.
  static String _headerJson(Map<String, Object?> arg) => jsonEncode(arg).replaceAllMapped(
        RegExp(r'[^\x00-\x7F]'),
        (m) => '\\u${m[0]!.codeUnitAt(0).toRadixString(16).padLeft(4, '0')}',
      );

  static String _errorSummary(http.Response response) {
    try {
      return ((jsonDecode(response.body) as Map)['error_summary'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Never _fail(http.Response response) {
    var summary = _errorSummary(response);
    // Ошибки формата запроса (400) Dropbox присылает обычным текстом.
    if (summary.isEmpty) summary = response.body.trim();
    if (summary.length > 300) summary = '${summary.substring(0, 300)}…';
    if (response.statusCode == 401) throw const StorageAuthException();
    if (summary.contains('insufficient_space')) throw const StorageQuotaException();
    if (response.statusCode == 429) {
      throw const StorageException('Dropbox временно ограничил запросы, попробуйте позже');
    }
    throw StorageException(
      'Ошибка Dropbox (${response.statusCode})${summary.isEmpty ? '' : ': $summary'}',
    );
  }
}
