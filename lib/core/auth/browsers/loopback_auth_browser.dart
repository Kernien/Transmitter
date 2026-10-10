import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../auth_browser.dart';

/// Вход через системный браузер, ответ облака принимает временный
/// HTTP-сервер на этом устройстве (localhost).
///
/// Основной способ на компьютере. На телефоне используется для облаков,
/// которые не разрешают возврат в приложение по своей схеме адреса (Google):
/// тогда на странице «Вход выполнен» есть кнопка возврата [returnUri].
class LoopbackAuthBrowser implements AuthBrowser {
  LoopbackAuthBrowser({this.returnUri});

  /// Фиксированный порт: облака требуют заранее прописать адрес возврата.
  static const int port = 47819;

  /// Ссылка, открывающая приложение после входа (на телефоне).
  final Uri? returnUri;

  @override
  Uri redirectUriFor(String providerCode) =>
      Uri.parse('http://localhost:$port/$providerCode');

  @override
  Future<Uri> authenticate(Uri authorizeUrl, Uri redirectUri) async {
    final servers = await _bindLoopback();
    final result = Completer<Uri>();
    final expectedPath = redirectUri.path.isEmpty ? '/' : redirectUri.path;

    for (final server in servers) {
      server.listen((request) async {
        if (request.uri.path != expectedPath) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        request.response.headers.contentType = ContentType.html;
        request.response.write(_successPage());
        await request.response.close();
        if (!result.isCompleted) {
          result.complete(redirectUri.replace(query: request.uri.query));
        }
      });
    }

    try {
      final opened = await launchUrl(
        authorizeUrl,
        mode: LaunchMode.externalApplication,
      );
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

  String _successPage() {
    final back = returnUri == null
        ? '<p>Можно закрыть эту вкладку и вернуться в Transmitter.</p>'
        : '<p><a href="${htmlEscape.convert(returnUri.toString())}" '
              'style="display:inline-block;padding:14px 28px;border-radius:24px;'
              'background:#3f51b5;color:#fff;text-decoration:none;font-size:18px">'
              'Вернуться в Transmitter</a></p>';
    return '<!DOCTYPE html><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Transmitter</title>'
        '<body style="font-family:sans-serif;text-align:center;padding-top:15vh">'
        '<h2>Вход выполнен</h2>$back';
  }

  /// Слушаем и IPv4, и IPv6: браузер может открыть `localhost` по любому из них.
  static Future<List<HttpServer>> _bindLoopback() async {
    final servers = <HttpServer>[];
    for (final address in [
      InternetAddress.loopbackIPv4,
      InternetAddress.loopbackIPv6,
    ]) {
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
