import 'package:http/http.dart' as http;

import 'oauth_token_manager.dart';

/// Выполняет запрос с действующим токеном; при ответе 401 один раз
/// обновляет токен и повторяет запрос.
Future<http.Response> sendWithBearer(
  OAuthTokenManager tokens,
  Future<http.Response> Function(String token) request,
) async {
  final response = await request(await tokens.accessToken());
  if (response.statusCode != 401) return response;
  return request(await tokens.refresh());
}
