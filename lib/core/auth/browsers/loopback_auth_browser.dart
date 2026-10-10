import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../auth_browser.dart';

/// Вход на компьютере: страница входа открывается в системном браузере,
/// а ответ облака принимает временный HTTP-сервер на localhost.
class LoopbackAuthBrowser implements AuthBrowser {
  /// Фиксированный порт: облака требуют заранее прописать точный адрес возврата.
  static const int port = 47819;

  static const String _successPage = '<!DOCTYPE html><meta charset="utf-8">'
      '<title>Transmitter</title>'
      '<body style="font-family:sans-serif;text-align:center;padding-top:15vh">'
      '<h2>Вход выполнен</h2><p>Можно закрыть эту вкладку и вернуться в Transmitter.</p>';

  @override
  Uri redirectUriFor(String providerCode) =>
      Uri.parse('http://localhost:$port/$providerCode');

  @override
  Future<Uri> authenticate(Uri authorizeUrl, Uri redirectUri) async {
    final servers = await _bindLoopback();
    final result = Completer<Uri>();

    for (final server in servers) {
      server.listen((request) async {
        if (request.uri.path != redirectUri.path) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        request.response.headers.contentType = ContentType.html;
        request.response.write(_successPage);
        await request.response.close();
        if (!result.isCompleted) {
          result.complete(redirectUri.replace(query: request.uri.query));
        }
      });
    }

    try {
      final opened = await launchUrl(authorizeUrl, mode: LaunchMode.externalApplication);
      if (!opened) throw const AuthException('Не удалось открыть браузер');
      return await result.future.timeout(
        authTimeout,
        onTimeout: () => throw const AuthCancelledException(),
      );
    } finally {
      for (final server in servers) {
        await server.close(force: true);
      }
    }
  }

  /// Слушаем и IPv4, и IPv6: браузер может открыть `localhost` по любому из них.
  static Future<List<HttpServer>> _bindLoopback() async {
    final servers = <HttpServer>[];
    for (final address in [InternetAddress.loopbackIPv4, InternetAddress.loopbackIPv6]) {
      try {
        servers.add(await HttpServer.bind(address, port));
      } on SocketException {
        // Адрес недоступен в системе или порт занят — пробуем следующий.
      }
    }
    if (servers.isEmpty) {
      throw const AuthException('Порт $port занят другой программой');
    }
    return servers;
  }
}
