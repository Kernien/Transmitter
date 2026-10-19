import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transmitter/core/errors/app_error.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/providers/mega/mega_adapter.dart';
import 'package:transmitter/core/storage/providers/mega/mega_api.dart';
import 'package:transmitter/core/storage/providers/mega/mega_crypto.dart';
import 'package:transmitter/core/storage/providers/mega/mega_session.dart';
import 'package:transmitter/core/storage/providers/mega/mega_storage.dart';

final Map<String, dynamic> vectors = jsonDecode(
  File('test/core/mega_vectors.json').readAsStringSync(),
) as Map<String, dynamic>;
final Map<String, dynamic> v2 = vectors['v2'] as Map<String, dynamic>;
final Map<String, dynamic> session = vectors['session'] as Map<String, dynamic>;

const String userHandle = 'USERHND1';

/// Поддельный сервер MEGA: API (`/cs`, `/sc`), загрузка и скачивание.
/// Шифрования не знает — хранит то, что прислал клиент.
class FakeMega {
  FakeMega() {
    nodes['ROOT0001'] = {'h': 'ROOT0001', 'p': '', 't': 2, 'ts': 1};
    nodes['TRASH001'] = {'h': 'TRASH001', 'p': '', 't': 4, 'ts': 1};
  }

  final Map<String, Map<String, Object?>> nodes = {};
  final Map<String, Uint8List> contents = {};
  final List<Map<String, Object?>> actions = [];
  final Map<int, ({int size, BytesBuilder data})> uploads = {};
  final List<String> commands = [];

  String? requiredMfa;
  bool sessionExpired = false;
  int againResponses = 0;
  int _counter = 0;
  int _clock = 100;

  late final http.Client client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final url = request.url;
    if (url.host == 'g.api.mega.co.nz' && url.path == '/cs') {
      final command =
          (jsonDecode(request.body) as List).single as Map<String, dynamic>;
      commands.add(command['a'] as String);
      return _json([_command(command, url.queryParameters['sid'])]);
    }
    if (url.host == 'g.api.mega.co.nz' && url.path == '/sc') {
      final from = int.parse(url.queryParameters['sn']!);
      if (from >= actions.length) {
        return _json({'w': 'https://wait', 'sn': '$from'});
      }
      return _json({'a': actions.sublist(from), 'sn': '${actions.length}'});
    }
    if (url.host == 'upload.example') {
      final segments = url.pathSegments;
      final id = int.parse(segments[0]);
      final offset = int.parse(segments[1]);
      final upload = uploads[id]!;
      expect(offset, upload.data.length, reason: 'куски по порядку');
      upload.data.add(request.bodyBytes);
      if (upload.data.length < upload.size) return http.Response.bytes([], 200);
      // Дескриптор — двоичный; клиент вернёт его в base64.
      final completion = utf8.encode('DONE${id.toString().padLeft(32, '0')}');
      contents[MegaCrypto.b64(completion)] = upload.data.toBytes();
      return http.Response.bytes(completion, 200);
    }
    if (url.host == 'download.example') {
      return http.Response.bytes(
        contents[nodes[url.pathSegments[0]]!['c']]!,
        200,
      );
    }
    return http.Response('not found', 404);
  }

  Object? _command(Map<String, dynamic> c, String? sid) {
    if (againResponses > 0) {
      againResponses--;
      return MegaApiException.eAgain;
    }
    switch (c['a']) {
      case 'us0':
        return {'v': 2, 's': v2['salt']};
      case 'us':
        if (c['uh'] != v2['userHash']) return MegaApiException.eNoEnt;
        if (requiredMfa != null && c['mfa'] != requiredMfa) {
          return MegaApiException.eMfaRequired;
        }
        return {
          'k': session['k'],
          'csid': session['csid'],
          'privk': session['privk'],
          'u': userHandle,
        };
    }
    if (sid != session['sid'] || sessionExpired) return MegaApiException.eSid;
    switch (c['a']) {
      case 'ug':
        return {'u': userHandle};
      case 'f':
        return {'f': nodes.values.toList(), 'sn': '${actions.length}'};
      case 'u':
        final id = _counter++;
        uploads[id] = (size: c['s'] as int, data: BytesBuilder());
        return {'p': 'https://upload.example/$id'};
      case 'p':
        final added = <Map<String, Object?>>[];
        for (final n in (c['n'] as List).cast<Map<String, dynamic>>()) {
          final handle = 'H${(_counter++).toString().padLeft(7, '0')}';
          final isFile = n['t'] == 0;
          final node = <String, Object?>{
            'h': handle,
            'p': c['t'],
            't': n['t'],
            'a': n['a'],
            'k': '$userHandle:${n['k']}',
            'ts': _clock++,
            if (isFile) 's': contents[n['h']]!.length,
            if (isFile) 'c': n['h'],
          };
          nodes[handle] = node;
          added.add(node);
        }
        actions.add({
          'a': 't',
          't': {'f': added},
        });
        return {'f': added};
      case 'g':
        final node = nodes[c['n']];
        if (node == null) return MegaApiException.eNoEnt;
        return {'g': 'https://download.example/${c['n']}', 's': node['s']};
      case 'd':
        if (nodes.remove(c['n']) == null) return MegaApiException.eNoEnt;
        nodes.removeWhere((_, n) => n['p'] == c['n']);
        actions.add({'a': 'd', 'n': c['n']});
        return 0;
    }
    return -2; // EARGS
  }

  static http.Response _json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

MegaCredentials credentials() => MegaCredentials(
  email: 'me@example.com',
  sessionId: session['sid'] as String,
  masterKey: Uint8List.fromList([
    for (var i = 0; i < 32; i += 2)
      int.parse(
        (session['masterKey'] as String).substring(i, i + 2),
        radix: 16,
      ),
  ]),
  userHandle: userHandle,
);

MegaStorage storageOn(FakeMega server, {Duration poll = Duration.zero}) =>
    MegaStorage(
      api: MegaApi(server.client, retryDelay: Duration.zero),
      credentials: credentials(),
      pollInterval: poll,
    );

Uint8List bytesOf(int size) =>
    Uint8List.fromList([for (var i = 0; i < size; i++) (i * 7) & 0xff]);

void main() {
  group('вход', () {
    test('почта и пароль → сеанс и мастер-ключ', () async {
      final server = FakeMega();
      final creds = await MegaAuthenticator(
        server.client,
      ).signIn(email: '  Me@Example.com ', password: v2['password'] as String);
      expect(creds.sessionId, session['sid']);
      expect(creds.email, 'me@example.com');
      expect(creds.userHandle, userHandle);
      final restored = MegaCredentials.decode(creds.encode());
      expect(restored.masterKey, credentials().masterKey);
    });

    test('неверный пароль', () async {
      final server = FakeMega();
      await expectLater(
        MegaAuthenticator(server.client)
            .signIn(email: 'me@example.com', password: 'wrong'),
        throwsA(
          isA<StorageAuthException>().having(
            (e) => e.code,
            'code',
            ErrorCode.cloudWrongPassword,
          ),
        ),
      );
    });

    test(
      'двухфакторная аутентификация: запрос кода, неверный и верный код',
      () async {
        final server = FakeMega()..requiredMfa = '123456';
        final auth = MegaAuthenticator(server.client);
        final password = v2['password'] as String;
        await expectLater(
          auth.signIn(email: 'me@example.com', password: password),
          throwsA(isA<SecondFactorRequiredException>()),
        );
        await expectLater(
          auth.signIn(
            email: 'me@example.com',
            password: password,
            secondFactorCode: '000000',
          ),
          throwsA(
            isA<StorageException>().having(
              (e) => e.code,
              'code',
              ErrorCode.cloudSecondFactorWrong,
            ),
          ),
        );
        final creds = await auth.signIn(
          email: 'me@example.com',
          password: password,
          secondFactorCode: ' 123456 ',
        );
        expect(creds.sessionId, session['sid']);
      },
    );

    test(
      'вход через CloudConnectionService сохраняет сеанс, не пароль',
      () async {
        final server = FakeMega();
        final store = InMemoryKeyValueStore();
        final service = CloudConnectionService(
          CloudProviderRegistry([MegaAdapter(client: server.client)]),
          store,
        );
        await service.connectWithPassword(
          CloudProviderId.mega,
          email: 'me@example.com',
          password: v2['password'] as String,
        );
        expect(service.isConnected(CloudProviderId.mega), isTrue);
        final saved = await store.read('cloud_credentials.mega');
        expect(saved, isNot(contains(v2['password'] as String)));
        expect(MegaCredentials.decode(saved!).sessionId, session['sid']);
      },
    );
  });

  group('хранилище', () {
    test('папки, загрузка, перезапись, скачивание, удаление', () async {
      final server = FakeMega();
      final storage = storageOn(server);
      expect(await storage.listFiles('vault/posts'), isEmpty);

      await storage.ensureFolder('vault/posts');
      await storage.ensureFolder('vault/posts');
      final folders = server.nodes.values.where((n) => n['t'] == 1);
      expect(
        folders.length,
        3,
        reason: 'Transmitter, vault, posts — без двойников',
      );

      final first = bytesOf(1000);
      await storage.upload('vault/posts/a.bin', first);
      expect(await storage.download('vault/posts/a.bin'), first);

      // Перезапись: остаётся одна версия, новая.
      final second = bytesOf(3 * 1048576 + 5);
      await storage.upload('vault/posts/a.bin', second);
      final files = await storage.listFiles('vault/posts');
      expect(files.map((f) => (f.name, f.size)), [('a.bin', second.length)]);
      expect(
        server.nodes.values.where((n) => n['t'] == 0).length,
        1,
        reason: 'старая версия удалена',
      );
      expect(await storage.download('vault/posts/a.bin'), second);

      await storage.upload('vault/posts/empty.bin', Uint8List(0));
      expect(await storage.download('vault/posts/empty.bin'), isEmpty);

      await storage.delete('vault/posts/a.bin');
      await storage.delete('vault/posts/a.bin');
      expect((await storage.listFiles('vault/posts')).map((f) => f.name), [
        'empty.bin',
      ]);
      await expectLater(
        storage.download('vault/posts/a.bin'),
        throwsA(isA<StorageNotFoundException>()),
      );
    });

    test('большой файл уходит несколькими кусками по границам MAC', () async {
      final server = FakeMega();
      final storage = storageOn(server);
      final data = bytesOf(20 * 1048576 + 3);
      await storage.upload('big.bin', data);
      expect(await storage.download('big.bin'), data);
    });

    test('другое устройство видит изменения через журнал /sc', () async {
      final server = FakeMega();
      final phone = storageOn(server);
      final laptop = storageOn(server);
      await phone.upload('v/one.bin', bytesOf(10));
      // Ноутбук загружает дерево целиком.
      expect((await laptop.listFiles('v')).map((f) => f.name), ['one.bin']);
      final fullLoads = server.commands.where((c) => c == 'f').length;

      await phone.upload('v/two.bin', bytesOf(20));
      await phone.delete('v/one.bin');
      // А дальше — только изменения.
      expect((await laptop.listFiles('v')).map((f) => f.name), ['two.bin']);
      expect(server.commands.where((c) => c == 'f').length, fullLoads);
      expect(await laptop.download('v/two.bin'), bytesOf(20));
    });

    test(
      'чужие узлы и папки с тем же именем вне папки приложения не видны',
      () async {
        final server = FakeMega();
        server.nodes['FOREIGN1'] = {
          'h': 'FOREIGN1',
          'p': 'ROOT0001',
          't': 1,
          'a': 'garbage',
          'k': 'OTHERUSR:AAAAAAAAAAAAAAAAAAAAAA',
          'ts': 5,
        };
        final storage = storageOn(server);
        await storage.upload('x.bin', bytesOf(5));
        expect((await storage.listFiles('')).map((f) => f.name), ['x.bin']);
      },
    );

    test('временная ошибка EAGAIN повторяется', () async {
      final server = FakeMega()..againResponses = 2;
      final storage = storageOn(server);
      expect(await storage.listFiles(''), isEmpty);
    });

    test('истёкший сеанс → нужно войти заново', () async {
      final server = FakeMega()..sessionExpired = true;
      await expectLater(
        storageOn(server).listFiles(''),
        throwsA(isA<StorageAuthException>()),
      );
    });
  });
}
