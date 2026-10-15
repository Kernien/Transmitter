// Проверка для «публичных досок»: можно ли читать файлы из облака владельца
// по публичной ссылке без входа — из приложения и из браузера (CORS), и
// остаётся ли ссылка прежней после обновления файла.
//
// Запуск из папки проекта (откроется браузер для входа в каждое облако):
//   dart run tool/check_public_links.dart <Google API key>
//
// Тестовый файл создаётся в папке приложения и в конце удаляется.
// ignore_for_file: avoid_print — это консольная утилита.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

const port = 47819;
const webOrigin = 'https://kernien.github.io';
final client = http.Client();

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Использование: dart run tool/check_public_links.dart <Google API key>',
    );
    exit(64);
  }
  final config = {
    ..._readJson('config/dev.json'),
    ..._readJson('config/secrets.json'),
  };
  final results = <String, bool>{};
  try {
    results.addAll(await checkDropbox(config['DROPBOX_APP_KEY'] as String));
  } catch (e) {
    print('Dropbox: ошибка проверки — $e');
  }
  try {
    results.addAll(
      await checkGoogle(
        clientId: config['GOOGLE_DESKTOP_CLIENT_ID'] as String,
        clientSecret: config['GOOGLE_DESKTOP_CLIENT_SECRET'] as String? ?? '',
        apiKey: args.first,
      ),
    );
  } catch (e) {
    print('Google Drive: ошибка проверки — $e');
  }
  print('\n==== Итог ====');
  results.forEach((name, ok) => print('${ok ? 'OK  ' : 'НЕТ '} $name'));
  client.close();
}

// ---------------------------------------------------------------- Dropbox

Future<Map<String, bool>> checkDropbox(String appKey) async {
  print('\n==== Dropbox ====');
  final redirect = 'http://localhost:$port/dropbox';
  final pkce = _Pkce();
  final code = await _signIn(
    Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': appKey,
      'response_type': 'code',
      'code_challenge': pkce.challenge,
      'code_challenge_method': 'S256',
      'redirect_uri': redirect,
      'token_access_type': 'online',
    }),
    '/dropbox',
  );
  final token =
      _json(
            await client.post(
              Uri.https('api.dropboxapi.com', '/oauth2/token'),
              body: {
                'code': code,
                'grant_type': 'authorization_code',
                'client_id': appKey,
                'code_verifier': pkce.verifier,
                'redirect_uri': redirect,
              },
            ),
          )['access_token']
          as String;
  final auth = {'Authorization': 'Bearer $token'};
  const path = '/_transmitter_link_check.bin';

  Future<void> upload(List<int> bytes) async => _ok(
    await client.post(
      Uri.https('content.dropboxapi.com', '/2/files/upload'),
      headers: {
        ...auth,
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({'path': path, 'mode': 'overwrite'}),
      },
      body: bytes,
    ),
  );

  final results = <String, bool>{};
  try {
    final first = _randomBytes();
    await upload(first);

    final linkResponse = await client.post(
      Uri.https(
        'api.dropboxapi.com',
        '/2/sharing/create_shared_link_with_settings',
      ),
      headers: {...auth, 'Content-Type': 'application/json'},
      body: utf8.encode(jsonEncode({'path': path})),
    );
    results['Dropbox: публичная ссылка создаётся (sharing.write)'] =
        linkResponse.statusCode == 200;
    if (linkResponse.statusCode != 200) {
      print(
        'Ссылка не создана: ${linkResponse.statusCode} ${linkResponse.body}',
      );
      return results;
    }
    final shared = Uri.parse(_json(linkResponse)['url'] as String);
    print('Ссылка: $shared');

    // Прямое скачивание: тот же адрес на dl.dropboxusercontent.com.
    final direct = shared.replace(
      host: 'dl.dropboxusercontent.com',
      queryParameters: {
        for (final e in shared.queryParameters.entries)
          if (e.key != 'dl') e.key: e.value,
      },
    );
    print('Прямой адрес: $direct');
    results.addAll(await _checkPublicRead('Dropbox', direct, expected: first));

    final second = _randomBytes();
    await upload(second);
    await Future<void>.delayed(const Duration(seconds: 2));
    results['Dropbox: после обновления файла по той же ссылке — новое содержимое'] =
        _same((await client.get(direct)).bodyBytes, second);
  } finally {
    await client.post(
      Uri.https('api.dropboxapi.com', '/2/files/delete_v2'),
      headers: {...auth, 'Content-Type': 'application/json'},
      body: utf8.encode(jsonEncode({'path': path})),
    );
    print('Тестовый файл удалён.');
  }
  return results;
}

// ----------------------------------------------------------- Google Drive

Future<Map<String, bool>> checkGoogle({
  required String clientId,
  required String clientSecret,
  required String apiKey,
}) async {
  print('\n==== Google Drive ====');
  final redirect = 'http://127.0.0.1:$port/';
  final pkce = _Pkce();
  final code = await _signIn(
    Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirect,
      'response_type': 'code',
      'scope': 'https://www.googleapis.com/auth/drive.file',
      'code_challenge': pkce.challenge,
      'code_challenge_method': 'S256',
    }),
    '/',
  );
  final token =
      _json(
            await client.post(
              Uri.https('oauth2.googleapis.com', '/token'),
              body: {
                'code': code,
                'client_id': clientId,
                'client_secret': clientSecret,
                'code_verifier': pkce.verifier,
                'grant_type': 'authorization_code',
                'redirect_uri': redirect,
              },
            ),
          )['access_token']
          as String;
  final auth = {'Authorization': 'Bearer $token'};

  final first = _randomBytes();
  const boundary = 'transmitter-link-check';
  final created = _json(
    await client.post(
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      ),
      headers: {
        ...auth,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: [
        ...utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'
          '${jsonEncode({'name': '_transmitter_link_check.bin'})}\r\n'
          '--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n',
        ),
        ...first,
        ...utf8.encode('\r\n--$boundary--'),
      ],
    ),
  );
  final id = created['id'] as String;
  final results = <String, bool>{};
  try {
    final permission = await client.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$id/permissions'),
      headers: {...auth, 'Content-Type': 'application/json'},
      body: utf8.encode(jsonEncode({'role': 'reader', 'type': 'anyone'})),
    );
    results['Google Drive: доступ «всем по ссылке» (drive.file)'] =
        permission.statusCode == 200;
    if (permission.statusCode != 200) {
      print('Доступ не открыт: ${permission.statusCode} ${permission.body}');
      return results;
    }
    final public = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$id?alt=media&key=$apiKey',
    );
    results.addAll(
      await _checkPublicRead('Google Drive', public, expected: first),
    );

    final second = _randomBytes();
    _ok(
      await client.patch(
        Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files/$id?uploadType=media',
        ),
        headers: {...auth, 'Content-Type': 'application/octet-stream'},
        body: second,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    results['Google Drive: после обновления файла по той же ссылке — новое содержимое'] =
        _same((await client.get(public)).bodyBytes, second);
  } finally {
    await client.delete(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$id'),
      headers: auth,
    );
    print('Тестовый файл удалён.');
  }
  return results;
}

// ------------------------------------------------------------------ Общее

/// Чтение без входа: как приложение и как браузер с сайта веб-версии.
Future<Map<String, bool>> _checkPublicRead(
  String cloud,
  Uri url, {
  required List<int> expected,
}) async {
  final plain = await client.get(url);
  print('Без входа: ${plain.statusCode}, ${plain.bodyBytes.length} байт');
  final fromWeb = await client.get(url, headers: {'Origin': webOrigin});
  final allowOrigin = fromWeb.headers['access-control-allow-origin'];
  print(
    'С сайта $webOrigin: ${fromWeb.statusCode}, '
    'Access-Control-Allow-Origin: ${allowOrigin ?? '—'}',
  );
  return {
    '$cloud: скачивание без входа (приложение)':
        plain.statusCode == 200 && _same(plain.bodyBytes, expected),
    '$cloud: скачивание из браузера (CORS)':
        fromWeb.statusCode == 200 &&
        (allowOrigin == '*' || allowOrigin == webOrigin),
  };
}

/// Открывает вход в браузере и ждёт ответа на локальном сервере.
Future<String> _signIn(Uri authorizeUrl, String path) async {
  final servers = <HttpServer>[];
  for (final address in [
    InternetAddress.loopbackIPv4,
    InternetAddress.loopbackIPv6,
  ]) {
    try {
      servers.add(await HttpServer.bind(address, port));
    } on SocketException {
      // Адрес недоступен — хватит другого.
    }
  }
  if (servers.isEmpty) {
    throw StateError('Порт $port занят — закройте Transmitter');
  }
  print('Открываю браузер для входа…');
  await Process.run('rundll32', [
    'url.dll,FileProtocolHandler',
    '$authorizeUrl',
  ]);
  try {
    final request = await servers
        .map((s) => s.firstWhere((r) => r.uri.path == path))
        .reduce((a, b) => Future.any([a, b]));
    request.response
      ..headers.contentType = ContentType.html
      ..write('<meta charset="utf-8"><h2>Готово, вернитесь в терминал</h2>');
    await request.response.close();
    final code = request.uri.queryParameters['code'];
    if (code == null) throw StateError('Вход отменён: ${request.uri.query}');
    return code;
  } finally {
    for (final s in servers) {
      await s.close(force: true);
    }
  }
}

class _Pkce {
  _Pkce() : verifier = base64Url.encode(_randomBytes(48)).replaceAll('=', '');

  final String verifier;

  String get challenge => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
}

List<int> _randomBytes([int length = 1024]) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, dynamic> _json(http.Response response) {
  _ok(response);
  return jsonDecode(response.body) as Map<String, dynamic>;
}

void _ok(http.Response response) {
  if (response.statusCode != 200) {
    throw StateError(
      '${response.request?.url}: ${response.statusCode} ${response.body}',
    );
  }
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  return file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      : {};
}
