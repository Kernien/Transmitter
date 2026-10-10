// Раздаёт собранную веб-версию (build/web) на http://localhost:47820.
//
// Запуск:
//   flutter build web --dart-define-from-file=config/dev.json
//   dart run tool/serve_web.dart
//
// Слушает localhost по IPv4 и IPv6: браузеры обращаются к localhost по
// любому из них. Порт 47820 прописан как адрес возврата в консоли Dropbox.
import 'dart:io';

const int port = 47820;

const Map<String, String> _mimeTypes = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'mjs': 'text/javascript; charset=utf-8',
  'json': 'application/json',
  'css': 'text/css',
  'wasm': 'application/wasm',
  'png': 'image/png',
  'ico': 'image/x-icon',
  'svg': 'image/svg+xml',
  'otf': 'font/otf',
  'ttf': 'font/ttf',
  'bin': 'application/octet-stream',
  'frag': 'application/octet-stream',
};

Future<void> main() async {
  final root = Directory('build/web');
  if (!root.existsSync()) {
    stderr.writeln('Нет папки build/web. Сначала выполните: '
        'flutter build web --dart-define-from-file=config/dev.json');
    exitCode = 1;
    return;
  }

  final servers = <HttpServer>[];
  for (final address in [InternetAddress.loopbackIPv4, InternetAddress.loopbackIPv6]) {
    try {
      servers.add(await HttpServer.bind(address, port));
    } on SocketException catch (e) {
      stderr.writeln('Не удалось занять ${address.address}:$port — ${e.message}');
    }
  }
  if (servers.isEmpty) {
    exitCode = 1;
    return;
  }

  for (final server in servers) {
    server.listen((request) => _serve(root, request));
  }
  stdout.writeln('Transmitter Web: http://localhost:$port  (Ctrl+C — остановить)');
}

Future<void> _serve(Directory root, HttpRequest request) async {
  final response = request.response;
  var path = Uri.decodeComponent(request.uri.path);
  if (path.endsWith('/')) path += 'index.html';

  final file = File('${root.path}$path');
  // Не выпускаем запросы за пределы build/web.
  final inside = !path.split(RegExp(r'[/\\]')).contains('..');
  final target = inside && file.existsSync() ? file : File('${root.path}/index.html');

  final extension = target.path.split('.').last.toLowerCase();
  response.headers
    ..set(HttpHeaders.contentTypeHeader, _mimeTypes[extension] ?? 'application/octet-stream')
    ..set(HttpHeaders.cacheControlHeader, 'no-cache');
  await response.addStream(target.openRead());
  await response.close();
}
