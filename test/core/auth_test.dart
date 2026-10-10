import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/auth/oauth_credentials.dart';
import 'package:transmitter/core/auth/oauth_token_manager.dart';
import 'package:transmitter/core/auth/pkce.dart';

void main() {
  group('Pkce', () {
    test('challenge совпадает с примером из RFC 7636', () {
      final pkce = Pkce.fromVerifier(
        'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
      );
      expect(pkce.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    });

    test(
      'сгенерированный verifier — 64 допустимых символа, каждый раз новый',
      () {
        final a = Pkce.generate();
        expect(a.verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]{64}$')));
        expect(a.verifier, isNot(Pkce.generate().verifier));
      },
    );
  });

  group('OAuthCredentials', () {
    test('encode → decode', () {
      final c = OAuthCredentials(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.utc(2026, 1, 1, 12),
      );
      final d = OAuthCredentials.decode(c.encode());
      expect(d.accessToken, 'a');
      expect(d.refreshToken, 'r');
      expect(d.expiresAt, c.expiresAt);
    });
  });

  group('OAuthTokenManager', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    var refreshCalls = 0;
    OAuthCredentials? saved;

    OAuthTokenManager manager({required Duration validFor}) =>
        OAuthTokenManager(
          initial: OAuthCredentials(
            accessToken: 'old',
            refreshToken: 'refresh',
            expiresAt: now.add(validFor),
          ),
          clock: () => now,
          refresher: (refreshToken) async {
            refreshCalls++;
            expect(refreshToken, 'refresh');
            await Future<void>.delayed(Duration.zero);
            return OAuthCredentials(
              accessToken: 'new$refreshCalls',
              refreshToken: refreshToken,
              expiresAt: now.add(const Duration(hours: 4)),
            );
          },
          onChanged: (c) async => saved = c,
        );

    setUp(() {
      refreshCalls = 0;
      saved = null;
    });

    test('действующий токен отдаётся без обновления', () async {
      expect(
        await manager(validFor: const Duration(hours: 1)).accessToken(),
        'old',
      );
      expect(refreshCalls, 0);
    });

    test('истекающий токен обновляется и сохраняется', () async {
      expect(
        await manager(validFor: const Duration(seconds: 30)).accessToken(),
        'new1',
      );
      expect(saved?.accessToken, 'new1');
    });

    test('параллельные запросы обновляют токен один раз', () async {
      final m = manager(validFor: Duration.zero);
      final tokens = await Future.wait([
        m.accessToken(),
        m.accessToken(),
        m.refresh(),
      ]);
      expect(tokens, ['new1', 'new1', 'new1']);
      expect(refreshCalls, 1);
    });
  });
}
