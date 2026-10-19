import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'mega_crypto.dart';

/// Ошибка API MEGA: отрицательный код из ответа сервера.
class MegaApiException implements Exception {
  const MegaApiException(this.code);

  final int code;

  static const int eAgain = -3;
  static const int eRateLimit = -4;
  static const int eFailed = -5;
  static const int eTooMany = -6;
  static const int eExpired = -8;
  static const int eNoEnt = -9;
  static const int eAccess = -11;
  static const int eSid = -15;
  static const int eBlocked = -16;
  static const int eOverQuota = -17;
  static const int eTempUnavailable = -18;
  static const int eGoingOverQuota = -24;
  static const int eMfaRequired = -26;

  @override
  String toString() => 'MEGA error $code';
}

/// Запросы к API MEGA (`https://g.api.mega.co.nz/cs`).
///
/// Команда — JSON-объект вида `{"a": "команда", ...}`. Временные ошибки
/// (EAGAIN, 500, 503) повторяются с паузой, на «hashcash» отвечаем сами.
class MegaApi {
  MegaApi(
    this._client, {
    this.sid,
    this.gateway = defaultGateway,
    @visibleForTesting this.retryDelay = const Duration(seconds: 1),
  });

  static const String defaultGateway = 'https://g.api.mega.co.nz/';
  static const int _maxRetries = 4;

  final http.Client _client;
  final String gateway;
  final Duration retryDelay;

  /// Сеанс после входа; без него доступны только команды входа.
  String? sid;

  int _sequence = Random().nextInt(0x7fffffff);

  /// Выполняет команду и возвращает её результат (объект, число, строку).
  /// Отрицательный код — [MegaApiException].
  Future<Object?> call(Map<String, Object?> command) async {
    final id = _sequence++;
    String? hashcash;
    for (var attempt = 0; ; attempt++) {
      final query = {'id': '$id', 'sid': ?sid};
      final response = await _client.post(
        Uri.parse('${gateway}cs').replace(queryParameters: query),
        headers: {'Content-Type': 'application/json', 'X-Hashcash': ?hashcash},
        body: jsonEncode([command]),
      );
      final challenge = response.headers['x-hashcash'];
      if (challenge != null && challenge.isNotEmpty && attempt < _maxRetries) {
        hashcash = kIsWeb
            ? await MegaCrypto.solveHashcash(challenge)
            : await compute(MegaCrypto.solveHashcash, challenge);
        continue;
      }
      Object? result;
      if (response.statusCode == 500 || response.statusCode == 503) {
        result = MegaApiException.eAgain;
      } else if (response.statusCode != 200) {
        throw http.ClientException(
          'MEGA HTTP ${response.statusCode}',
          response.request?.url,
        );
      } else {
        result = jsonDecode(response.body);
        if (result is List) result = result.isEmpty ? null : result.first;
      }
      if (result is int && result < 0) {
        if (result == MegaApiException.eAgain && attempt < _maxRetries) {
          await Future<void>.delayed(retryDelay * pow(2, attempt));
          continue;
        }
        throw MegaApiException(result);
      }
      return result;
    }
  }

  /// Изменения в облаке после [sn] (`/sc`). Ответ с `w` — изменений нет.
  Future<Map<String, Object?>> poll(String sn) async {
    for (var attempt = 0; ; attempt++) {
      final response = await _client.post(
        Uri.parse('${gateway}sc')
            .replace(queryParameters: {'sn': sn, 'sid': ?sid, 'ssl': '1'}),
      );
      Object? result = response.statusCode == 200
          ? jsonDecode(response.body)
          : MegaApiException.eAgain;
      if (result is List) result = result.isEmpty ? null : result.first;
      if (result is int) {
        if (result == MegaApiException.eAgain && attempt < _maxRetries) {
          await Future<void>.delayed(retryDelay * pow(2, attempt));
          continue;
        }
        throw MegaApiException(result);
      }
      if (result is! Map<String, Object?>) {
        throw const FormatException('MEGA: unexpected /sc response');
      }
      return result;
    }
  }

  /// Отправляет кусок зашифрованного файла по адресу загрузки. Последний
  /// кусок возвращает дескриптор завершённой загрузки.
  Future<Uint8List> uploadChunk(String url, int offset, Uint8List bytes) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _client.post(
          Uri.parse('$url/$offset'),
          body: bytes,
        );
        if (response.statusCode != 200) {
          throw http.ClientException(
            'MEGA upload HTTP ${response.statusCode}',
            response.request?.url,
          );
        }
        final body = response.bodyBytes;
        // Ошибка приходит текстом: «-3», «-17»…
        if (body.isNotEmpty && body.length < 6 && body[0] == 0x2d) {
          final code = int.tryParse(ascii.decode(body, allowInvalid: true));
          if (code != null) throw MegaApiException(code);
        }
        return body;
      } on http.ClientException {
        if (attempt >= 2) rethrow;
        await Future<void>.delayed(retryDelay * pow(2, attempt));
      }
    }
  }

  /// Скачивает зашифрованный файл по временному адресу из команды `g`.
  Future<Uint8List> downloadBytes(String url) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _client.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw http.ClientException(
            'MEGA download HTTP ${response.statusCode}',
            response.request?.url,
          );
        }
        return response.bodyBytes;
      } on http.ClientException {
        if (attempt >= 2) rethrow;
        await Future<void>.delayed(retryDelay * pow(2, attempt));
      }
    }
  }
}
