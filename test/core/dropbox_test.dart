import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transmitter/core/auth/auth_browser.dart';
import 'package:transmitter/core/auth/oauth_credentials.dart';
import 'package:transmitter/core/auth/oauth_token_manager.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/providers/dropbox/dropbox_authenticator.dart';
import 'package:transmitter/core/storage/providers/dropbox/dropbox_storage.dart';

/// Имитация браузера: «входит» и возвращает заданные параметры.
class FakeAuthBrowser implements AuthBrowser {
  FakeAuthBrowser(this.respond);

  final Map<String, String> Function(Uri authorizeUrl) respond;
  Uri? openedUrl;

  @override
  Uri redirectUriFor(String providerCode) => Uri.parse('http://localhost:1/$providerCode');

  @override
  Future<Uri> authenticate(Uri authorizeUrl, Uri redirectUri) async {
    openedUrl = authorizeUrl;
    return redirectUri.replace(queryParameters: respond(authorizeUrl));
  }
}

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('DropboxAuthenticator', () {
    final now = DateTime.utc(2026, 1, 1);

    test('вход: PKCE-параметры, обмен кода на токены', () async {
      final browser = FakeAuthBrowser((url) => {
            'code': 'the-code',
            'state': url.queryParameters['state']!,
          });
      late Map<String, String> tokenRequest;
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.dropboxapi.com/oauth2/token');
        tokenRequest = request.bodyFields;
        return jsonResponse({
          'access_token': 'acc',
          'refresh_token': 'ref',
          'expires_in': 14400,
        });
      });
      final auth = DropboxAuthenticator(
        appKey: 'key',
        browser: browser,
        client: client,
        clock: () => now,
      );

      final creds = await auth.signIn();

      final q = browser.openedUrl!.queryParameters;
      expect(browser.openedUrl!.host, 'www.dropbox.com');
      expect(q['client_id'], 'key');
      expect(q['code_challenge_method'], 'S256');
      expect(q['token_access_type'], 'offline');
      expect(q['redirect_uri'], 'http://localhost:1/dropbox');

      expect(tokenRequest['grant_type'], 'authorization_code');
      expect(tokenRequest['code'], 'the-code');
      expect(tokenRequest['code_verifier'], hasLength(64));
      expect(tokenRequest['redirect_uri'], 'http://localhost:1/dropbox');

      expect(creds.accessToken, 'acc');
      expect(creds.refreshToken, 'ref');
      expect(creds.expiresAt, now.add(const Duration(hours: 4)));
    });

    test('чужой state отклоняется', () async {
      final auth = DropboxAuthenticator(
        appKey: 'key',
        browser: FakeAuthBrowser((_) => {'code': 'c', 'state': 'forged'}),
        client: MockClient((_) async => fail('токен не должен запрашиваться')),
      );
      expect(auth.signIn(), throwsA(isA<AuthException>()));
    });

    test('отказ пользователя — AuthCancelledException', () async {
      final auth = DropboxAuthenticator(
        appKey: 'key',
        browser: FakeAuthBrowser((_) => {'error': 'access_denied'}),
        client: MockClient((_) async => fail('не должен вызываться')),
      );
      expect(auth.signIn(), throwsA(isA<AuthCancelledException>()));
    });

    test('обновление сохраняет прежний refresh token', () async {
      final auth = DropboxAuthenticator(
        appKey: 'key',
        browser: FakeAuthBrowser((_) => {}),
        client: MockClient((request) async {
          expect(request.bodyFields['grant_type'], 'refresh_token');
          return jsonResponse({'access_token': 'acc2', 'expires_in': 100});
        }),
      );
      final creds = await auth.refresh('ref');
      expect(creds.accessToken, 'acc2');
      expect(creds.refreshToken, 'ref');
    });

    test('отозванный доступ — StorageAuthException', () async {
      final auth = DropboxAuthenticator(
        appKey: 'key',
        browser: FakeAuthBrowser((_) => {}),
        client: MockClient((_) async => jsonResponse({'error': 'invalid_grant'}, 400)),
      );
      expect(auth.refresh('ref'), throwsA(isA<StorageAuthException>()));
    });
  });

  group('DropboxStorage', () {
    late List<http.Request> requests;
    late Future<http.Response> Function(http.Request) handler;
    late int refreshes;

    DropboxStorage storage() => DropboxStorage(
          client: MockClient((r) {
            requests.add(r);
            return handler(r);
          }),
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
                expiresAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
              );
            },
          ),
        );

    setUp(() {
      requests = [];
      refreshes = 0;
    });

    test('listFiles: пути, постраничная загрузка, только файлы', () async {
      handler = (r) async {
        if (r.url.path.endsWith('/list_folder')) {
          expect(jsonDecode(r.body)['path'], '/v1/posts');
          return jsonResponse({
            'entries': [
              {'.tag': 'file', 'name': 'a.post', 'size': 10},
              {'.tag': 'folder', 'name': 'sub'},
            ],
            'cursor': 'c1',
            'has_more': true,
          });
        }
        expect(jsonDecode(r.body)['cursor'], 'c1');
        return jsonResponse({
          'entries': [
            {'.tag': 'file', 'name': 'b.post', 'size': 20},
          ],
          'cursor': 'c2',
          'has_more': false,
        });
      };
      final files = await storage().listFiles('v1/posts');
      expect(files.map((f) => f.name), ['a.post', 'b.post']);
      expect(requests.first.headers['Authorization'], 'Bearer tok');
    });

    test('RPC-запросы отправляют Content-Type ровно application/json', () async {
      // Dropbox отвечает 400 на «application/json; charset=utf-8».
      handler = (_) async => jsonResponse({'entries': [], 'cursor': 'c', 'has_more': false});
      await storage().listFiles('');
      expect(requests.single.headers['Content-Type'], 'application/json');
    });

    test('текст ошибки 400 попадает в сообщение', () async {
      handler = (_) async => http.Response('Error in call to API function: bad input', 400);
      expect(
        storage().listFiles(''),
        throwsA(isA<StorageException>().having((e) => e.message, 'message', contains('bad input'))),
      );
    });

    test('listFiles корня передаёт пустой путь', () async {
      handler = (r) async {
        expect(jsonDecode(r.body)['path'], '');
        return jsonResponse({'entries': [], 'cursor': 'c', 'has_more': false});
      };
      expect(await storage().listFiles(''), isEmpty);
    });

    test('listFiles несуществующей папки — пустой список', () async {
      handler = (_) async => jsonResponse({'error_summary': 'path/not_found/..'}, 409);
      expect(await storage().listFiles('nope'), isEmpty);
    });

    test('upload: заголовки и тело', () async {
      handler = (r) async => jsonResponse({'name': 'x'});
      await storage().upload('v1/files/x.bin', Uint8List.fromList([1, 2, 3]));
      final r = requests.single;
      expect(r.url.toString(), 'https://content.dropboxapi.com/2/files/upload');
      expect(jsonDecode(r.headers['Dropbox-API-Arg']!),
          {'path': '/v1/files/x.bin', 'mode': 'overwrite', 'mute': true});
      expect(r.headers['Content-Type'], 'application/octet-stream');
      expect(r.bodyBytes, [1, 2, 3]);
    });

    test('Dropbox-API-Arg экранирует не-ASCII символы', () async {
      handler = (r) async => jsonResponse({});
      await storage().upload('папка/файл', Uint8List(0));
      final header = requests.single.headers['Dropbox-API-Arg']!;
      expect(header, isNot(contains('п')));
      expect(jsonDecode(header)['path'], '/папка/файл');
    });

    test('download возвращает байты, отсутствующий файл — StorageNotFoundException', () async {
      handler = (r) async => http.Response.bytes([9, 8, 7], 200);
      expect(await storage().download('a/b'), [9, 8, 7]);

      handler = (_) async => jsonResponse({'error_summary': 'path/not_found/'}, 409);
      expect(storage().download('a/c'), throwsA(isA<StorageNotFoundException>()));
    });

    test('ensureFolder игнорирует «уже существует»', () async {
      handler = (_) async => jsonResponse({'error_summary': 'path/conflict/folder/'}, 409);
      await storage().ensureFolder('v1/posts');
      expect(jsonDecode(requests.single.body)['path'], '/v1/posts');
    });

    test('delete игнорирует отсутствующий файл', () async {
      handler = (_) async => jsonResponse({'error_summary': 'path_lookup/not_found/'}, 409);
      await storage().delete('v1/posts/x');
    });

    test('при 401 токен обновляется и запрос повторяется', () async {
      handler = (r) async => r.headers['Authorization'] == 'Bearer tok'
          ? jsonResponse({'error_summary': 'expired_access_token/'}, 401)
          : jsonResponse({'entries': [], 'cursor': 'c', 'has_more': false});
      expect(await storage().listFiles(''), isEmpty);
      expect(refreshes, 1);
      expect(requests.map((r) => r.headers['Authorization']), ['Bearer tok', 'Bearer tok2']);
    });

    test('нехватка места — StorageQuotaException', () async {
      handler = (_) async =>
          jsonResponse({'error_summary': 'path/insufficient_space/..'}, 409);
      expect(storage().upload('a', Uint8List(1)), throwsA(isA<StorageQuotaException>()));
    });
  });
}
