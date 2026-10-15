import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transmitter/core/auth/auth_browser.dart';
import 'package:transmitter/core/auth/oauth_credentials.dart';
import 'package:transmitter/core/auth/oauth_token_manager.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/providers/google_drive/google_drive_authenticator.dart';
import 'package:transmitter/core/storage/providers/google_drive/google_drive_storage.dart';
import 'package:transmitter/core/storage/providers/google_drive/google_public_reader.dart';

const _folderMime = 'application/vnd.google-apps.folder';

/// Имитация Google Drive API v3 в памяти — ровно в том объёме, который
/// использует GoogleDriveStorage.
class FakeDrive {
  final Map<String, Map<String, dynamic>> items = {};
  final Map<String, Uint8List> contents = {};
  final Map<String, Map<String, dynamic>> _sessions = {};

  /// Файлы, открытые «всем, у кого есть ссылка».
  final Set<String> public = {};
  static const apiKey = 'api-key';
  int _next = 0;
  int requests = 0;
  String? expectedToken = 'tok';

  late final MockClient client = MockClient(_handle);

  String _id() => 'id${_next++}';

  Map<String, dynamic>? byName(String name) =>
      items.values.where((i) => i['name'] == name).firstOrNull;

  Future<http.Response> _handle(http.Request r) async {
    requests++;
    final url = r.url;
    if (url.host == 'upload.example') return _finishResumable(r);
    // Публичное чтение: без токена, с API-ключом.
    if (url.queryParameters.containsKey('key')) {
      final id = url.pathSegments.last;
      final data = contents[id];
      return url.queryParameters['key'] == apiKey &&
              public.contains(id) &&
              data != null
          ? http.Response.bytes(data, 200)
          : _json({'error': {}}, 404);
    }
    if (expectedToken != null &&
        r.headers['Authorization'] != 'Bearer $expectedToken') {
      return _json({
        'error': {'message': 'Invalid Credentials'},
      }, 401);
    }
    final upload = url.path.startsWith('/upload/drive/v3/files');
    final segments = url.pathSegments;
    if (segments.contains('permissions')) {
      final id = segments[segments.indexOf('files') + 1];
      if (!items.containsKey(id)) return _json({'error': {}}, 404);
      if (r.method == 'POST') {
        expect(jsonDecode(r.body), {'role': 'reader', 'type': 'anyone'});
        public.add(id);
        return _json({'id': 'anyoneWithLink'});
      }
      expect(segments.last, 'anyoneWithLink');
      return http.Response('', public.remove(id) ? 204 : 404);
    }
    final fileId = segments.last == 'files' ? null : segments.last;

    if (upload && url.queryParameters['uploadType'] == 'multipart') {
      final (meta, data) = _parseMultipart(r);
      final id = _store(fileId, meta, data);
      return _json({'id': id});
    }
    if (upload && url.queryParameters['uploadType'] == 'resumable') {
      final session = 's${_next++}';
      _sessions[session] = {'fileId': fileId, 'meta': jsonDecode(r.body)};
      return http.Response(
        '',
        200,
        headers: {'location': 'https://upload.example/$session'},
      );
    }
    if (r.method == 'GET' && fileId == null) return _list(url.queryParameters);
    if (r.method == 'GET' && url.queryParameters['alt'] == 'media') {
      final data = contents[fileId];
      return data == null
          ? _json({'error': {}}, 404)
          : http.Response.bytes(data, 200);
    }
    if (r.method == 'POST' && fileId == null) {
      final meta = jsonDecode(r.body) as Map<String, dynamic>;
      return _json({'id': _store(null, meta, null)});
    }
    if (r.method == 'DELETE') {
      final existed = items.remove(fileId) != null;
      contents.remove(fileId);
      return http.Response('', existed ? 204 : 404);
    }
    return _json({
      'error': {'message': 'unexpected ${r.method} $url'},
    }, 500);
  }

  String _store(
    String? existingId,
    Map<String, dynamic> meta,
    Uint8List? data,
  ) {
    final id = existingId ?? _id();
    final item = items.putIfAbsent(id, () => {'id': id, 'createdTime': _next});
    if (meta['name'] != null) item['name'] = meta['name'];
    if (meta['parents'] != null) {
      item['parent'] = (meta['parents'] as List).first;
    }
    item['mimeType'] =
        meta['mimeType'] ?? item['mimeType'] ?? 'application/octet-stream';
    if (data != null) {
      contents[id] = data;
      item['size'] = '${data.length}';
    }
    return id;
  }

  http.Response _list(Map<String, String> query) {
    final q = query['q']!;
    final parent = RegExp(r"'([^']+)' in parents").firstMatch(q)!.group(1);
    final name = RegExp(r"name = '((?:[^'\\]|\\.)*)'")
        .firstMatch(q)
        ?.group(1)
        ?.replaceAll(r"\'", "'");
    final folderOnly = q.contains("mimeType = '$_folderMime'");
    final filesOnly = q.contains("mimeType != '$_folderMime'");
    final found =
        items.values.where((i) {
          final itemParent = i['parent'] ?? 'root';
          if (itemParent != parent) return false;
          if (name != null && i['name'] != name) return false;
          if (folderOnly && i['mimeType'] != _folderMime) return false;
          if (filesOnly && i['mimeType'] == _folderMime) return false;
          return true;
        }).toList()..sort(
          (a, b) =>
              (a['createdTime'] as int).compareTo(b['createdTime'] as int),
        );
    return _json({
      'files': [
        for (final i in found)
          {
            'id': i['id'],
            'name': i['name'],
            if (i['size'] != null) 'size': i['size'],
          },
      ],
    });
  }

  http.Response _finishResumable(http.Request r) {
    final session = _sessions.remove(r.url.pathSegments.last)!;
    final id = _store(
      session['fileId'] as String?,
      Map<String, dynamic>.from(session['meta'] as Map),
      r.bodyBytes,
    );
    return _json({'id': id});
  }

  (Map<String, dynamic>, Uint8List) _parseMultipart(http.Request r) {
    final boundary = r.headers['Content-Type']!.split('boundary=').last;
    final text = latin1.decode(r.bodyBytes);
    final parts = text.split('--$boundary');
    String body(String part) =>
        part.substring(part.indexOf('\r\n\r\n') + 4, part.length - 2);
    final meta = jsonDecode(
      utf8.decode(latin1.encode(body(parts[1]))),
    ) as Map<String, dynamic>;
    return (meta, Uint8List.fromList(latin1.encode(body(parts[2]))));
  }

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

class FakeBrowser implements AuthBrowser {
  FakeBrowser(this.respond);

  final Uri Function(Uri authorizeUrl, Uri redirect) respond;
  Uri? opened;

  @override
  Uri redirectUriFor(String providerCode) =>
      Uri.parse('https://app.example/auth.html');

  @override
  Future<Uri> authenticate(Uri authorizeUrl, Uri redirectUri) async {
    opened = authorizeUrl;
    return respond(authorizeUrl, redirectUri);
  }
}

void main() {
  group('GoogleDriveStorage', () {
    late FakeDrive drive;
    late int refreshes;

    GoogleDriveStorage storage() => GoogleDriveStorage(
      client: drive.client,
      tokens: OAuthTokenManager(
        initial: OAuthCredentials(
          accessToken: 'tok',
          refreshToken: 'ref',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        refresher: (r) async {
          refreshes++;
          return OAuthCredentials(
            accessToken: 'tok2',
            refreshToken: r,
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          );
        },
      ),
    );

    setUp(() {
      drive = FakeDrive();
      refreshes = 0;
    });

    test('папки создаются внутри видимой папки Transmitter', () async {
      await storage().ensureFolder('v1/posts');
      final root = drive.byName('Transmitter')!;
      expect(root['parent'], 'root'); // «Мой диск»
      expect(root['mimeType'], _folderMime);
      expect(drive.byName('v1')!['parent'], root['id']);
      expect(drive.byName('posts')!['parent'], drive.byName('v1')!['id']);
    });

    test('повторный ensureFolder не создаёт дубликатов', () async {
      await storage().ensureFolder('v1/posts');
      await storage().ensureFolder('v1/posts'); // новое устройство, без кеша
      expect(
        drive.items.values.where((i) => i['name'] == 'posts'),
        hasLength(1),
      );
    });

    test('загрузка, список, скачивание, удаление', () async {
      final s = storage();
      final data = Uint8List.fromList(List.generate(300, (i) => i % 256));
      await s.upload('v1/posts/a.post', data);
      await s.upload('v1/posts/b.post', Uint8List.fromList([1]));

      // Другое устройство видит файлы без общего кеша.
      final other = storage();
      expect(
        (await other.listFiles('v1/posts')).map((f) => f.name),
        unorderedEquals(['a.post', 'b.post']),
      );
      expect(await other.download('v1/posts/a.post'), data);

      await other.delete('v1/posts/a.post');
      expect((await storage().listFiles('v1/posts')).map((f) => f.name), [
        'b.post',
      ]);
      await other.delete('v1/posts/a.post'); // уже нет — без ошибки
    });

    test(
      'повторная загрузка того же пути перезаписывает файл, а не дублирует',
      () async {
        final s = storage();
        await s.upload('v1/x.bin', Uint8List.fromList([1]));
        await storage().upload('v1/x.bin', Uint8List.fromList([2, 2]));
        expect(
          drive.items.values.where((i) => i['name'] == 'x.bin'),
          hasLength(1),
        );
        expect(await storage().download('v1/x.bin'), [2, 2]);
      },
    );

    test('большой файл идёт возобновляемой загрузкой', () async {
      final big = Uint8List(GoogleDriveStorage.multipartLimit + 10);
      big[big.length - 1] = 7;
      await storage().upload('v1/files/big.bin', big);
      final back = await storage().download('v1/files/big.bin');
      expect(back.length, big.length);
      expect(back.last, 7);
    });

    test(
      'несуществующая папка — пустой список, файл — StorageNotFoundException',
      () async {
        expect(await storage().listFiles('nope'), isEmpty);
        expect(
          storage().download('nope/x'),
          throwsA(isA<StorageNotFoundException>()),
        );
      },
    );

    test('при 401 токен обновляется и запрос повторяется', () async {
      drive.expectedToken = 'tok2';
      expect(await storage().listFiles(''), isEmpty);
      expect(refreshes, 1);
    });

    test('нехватка места — StorageQuotaException', () async {
      final quota = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'message': 'quota',
              'errors': [
                {'reason': 'storageQuotaExceeded'},
              ],
            },
          }),
          403,
        ),
      );
      final s = GoogleDriveStorage(
        client: quota,
        tokens: OAuthTokenManager(
          initial: OAuthCredentials(
            accessToken: 'tok',
            refreshToken: 'r',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          refresher: (_) async => throw StateError('не должен вызываться'),
        ),
      );
      expect(s.ensureFolder('a'), throwsA(isA<StorageQuotaException>()));
    });

    test('публичный доступ: открыть, прочитать без входа, закрыть', () async {
      final s = storage();
      await s.upload('v1/board.bin', Uint8List.fromList([7, 8, 9]));
      final reader = GooglePublicReader(
        client: drive.client,
        apiKey: FakeDrive.apiKey,
      );

      final locator = await s.publish('v1/board.bin');
      expect(locator, drive.byName('board.bin')!['id']);
      expect(await reader.download(locator), [7, 8, 9]);

      // Обновлённый файл доступен по тому же адресу.
      await s.upload('v1/board.bin', Uint8List.fromList([1]));
      expect(await reader.download(locator), [1]);

      await s.unpublish('v1/board.bin', locator);
      expect(
        reader.download(locator),
        throwsA(isA<StorageNotFoundException>()),
      );
      // Повторное закрытие — без ошибки.
      await s.unpublish('v1/board.bin', locator);
    });

    test('открыть доступ к несуществующему файлу — not found', () {
      expect(
        storage().publish('v1/nope.bin'),
        throwsA(isA<StorageNotFoundException>()),
      );
    });
  });

  group('GoogleDriveAuthenticator', () {
    final now = DateTime.utc(2026, 1, 1);

    test('устройства: код + PKCE через 127.0.0.1, refresh token', () async {
      final browser = FakeBrowser(
        (url, redirect) => redirect.replace(
          queryParameters: {
            'code': 'c1',
            'state': url.queryParameters['state']!,
          },
        ),
      );
      late Map<String, String> token;
      final auth = GoogleDriveAuthenticator(
        clientId: 'desk',
        clientSecret: 'sec',
        browserFlow: false,
        browser: browser,
        client: MockClient((r) async {
          token = r.bodyFields;
          return http.Response(
            jsonEncode({
              'access_token': 'a',
              'refresh_token': 'r',
              'expires_in': 3599,
            }),
            200,
          );
        }),
        clock: () => now,
      );

      final creds = await auth.signIn();
      final q = browser.opened!.queryParameters;
      expect(q['redirect_uri'], 'http://127.0.0.1:47819/');
      expect(q['scope'], GoogleDriveAuthenticator.scope);
      expect(q['access_type'], 'offline');
      expect(q['code_challenge_method'], 'S256');
      expect(token['client_secret'], 'sec');
      expect(token['code_verifier'], hasLength(64));
      expect(creds.refreshToken, 'r');
      expect(creds.expiresAt, now.add(const Duration(seconds: 3599)));
    });

    test('без секрета он не отправляется', () async {
      late Map<String, String> token;
      final auth = GoogleDriveAuthenticator(
        clientId: 'desk',
        browserFlow: false,
        browser: FakeBrowser(
          (url, redirect) => redirect.replace(
            queryParameters: {
              'code': 'c',
              'state': url.queryParameters['state']!,
            },
          ),
        ),
        client: MockClient((r) async {
          token = r.bodyFields;
          return http.Response(
            jsonEncode({
              'access_token': 'a',
              'refresh_token': 'r',
              'expires_in': 1,
            }),
            200,
          );
        }),
      );
      await auth.signIn();
      expect(token.containsKey('client_secret'), isFalse);
    });

    test(
      'браузер: временный токен из фрагмента, обновление требует нового входа',
      () async {
        final browser = FakeBrowser(
          (url, redirect) => redirect.replace(
            fragment:
                'access_token=web-tok&expires_in=3599&token_type=Bearer'
                '&state=${url.queryParameters['state']}',
          ),
        );
        final auth = GoogleDriveAuthenticator(
          clientId: 'web',
          browserFlow: true,
          browser: browser,
          client: MockClient((_) async => fail('сервер токенов не нужен')),
          clock: () => now,
        );
        final creds = await auth.signIn();
        expect(browser.opened!.queryParameters['response_type'], 'token');
        expect(creds.accessToken, 'web-tok');
        expect(creds.refreshToken, isEmpty);
        expect(auth.refresh(''), throwsA(isA<StorageAuthException>()));
      },
    );

    test('чужой state и отказ пользователя', () async {
      GoogleDriveAuthenticator auth(Map<String, String> answer) =>
          GoogleDriveAuthenticator(
            clientId: 'desk',
            browserFlow: false,
            browser: FakeBrowser(
              (url, redirect) => redirect.replace(queryParameters: answer),
            ),
            client: MockClient((_) async => fail('не должен вызываться')),
          );
      expect(
        auth({'code': 'c', 'state': 'forged'}).signIn(),
        throwsA(isA<AuthException>()),
      );
      expect(
        auth({'error': 'access_denied'}).signIn(),
        throwsA(isA<AuthCancelledException>()),
      );
    });

    test('отозванный refresh token — StorageAuthException', () async {
      final auth = GoogleDriveAuthenticator(
        clientId: 'desk',
        browserFlow: false,
        browser: FakeBrowser((u, r) => r),
        client: MockClient(
          (_) async => http.Response('{"error":"invalid_grant"}', 400),
        ),
      );
      expect(auth.refresh('r'), throwsA(isA<StorageAuthException>()));
    });
  });
}
