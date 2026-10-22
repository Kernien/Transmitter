import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/crypto/board_signature.dart';
import 'package:transmitter/core/errors/app_error.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/providers/mega/mega_adapter.dart';
import 'package:transmitter/core/storage/providers/mega/mega_api.dart';
import 'package:transmitter/core/storage/providers/mega/mega_crypto.dart';
import 'package:transmitter/core/storage/providers/mega/mega_links.dart';
import 'package:transmitter/core/storage/providers/mega/mega_public_reader.dart';
import 'package:transmitter/core/storage/providers/mega/mega_session.dart';
import 'package:transmitter/core/storage/providers/mega/mega_storage.dart';
import 'package:transmitter/core/vault/reader_key.dart';
import 'package:transmitter/data/board_manifest_codec.dart';
import 'package:transmitter/data/board_publisher.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/domain/board_snapshot.dart';

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

  /// Папки с общим ключом для ссылок (`EXP`) и публичные дескрипторы узлов.
  final Set<String> exported = {};
  final Map<String, String> publicHandles = {};

  /// Ключи узлов для читателей: узел → (общая папка → ключ).
  final Map<String, Map<String, String>> readerKeys = {};

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
      final folderLink = url.queryParameters['n'];
      return _json([
        folderLink != null
            ? _readerCommand(command, folderLink)
            : _command(command, url.queryParameters['sid']),
      ]);
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
        return {
          'f': nodes.values.toList(),
          's': [
            for (final h in exported) {'h': h, 'u': 'EXP', 'r': 0, 'ts': 1},
          ],
          'ph': [
            for (final MapEntry(:key, :value) in publicHandles.entries)
              {'h': key, 'ph': value, 'ts': 1},
          ],
          'sn': '${actions.length}',
        };
      case 'u':
        final id = _counter++;
        uploads[id] = (size: c['s'] as int, data: BytesBuilder());
        return {'p': 'https://upload.example/$id'};
      case 'p':
        final added = <Map<String, Object?>>[];
        // В cr новые узлы называются так же, как в запросе (поле h).
        final created = <String, String>{};
        for (final n in (c['n'] as List).cast<Map<String, dynamic>>()) {
          final handle = 'H${(_counter++).toString().padLeft(7, '0')}';
          created[n['h'] as String] = handle;
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
        if (c['cr'] case final List cr) {
          _applyReaderKeys(cr, (ref) => created[ref]!);
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
        exported.remove(c['n']);
        publicHandles.remove(c['n']);
        actions.add({'a': 'd', 'n': c['n']});
        return 0;
      case 's2':
        final folder = c['n'] as String;
        final share = (c['s'] as List).single as Map;
        expect(share['u'], 'EXP');
        // Как настоящий сервер: старый формат с ok/ha отвергается (EAGAIN).
        if (c.containsKey('ok') || c.containsKey('ha')) {
          return MegaApiException.eAgain;
        }
        if (share['r'] == '') {
          exported.remove(folder);
        } else {
          exported.add(folder);
        }
        // cr внутри s2 настоящий сервер пропускает: ключи — только через k.
        actions.add({'a': 's', 'n': folder, 'u': 'EXP', 'r': share['r']});
        return {
          'r': [0],
        };
      case 'k':
        _applyReaderKeys(c['cr'] as List, (ref) => ref);
        return 0;
      case 'l':
        final handle = c['n'] as String;
        if (!nodes.containsKey(handle)) return MegaApiException.eNoEnt;
        if (c['d'] == 1) {
          publicHandles.remove(handle);
          actions.add({'a': 'ph', 'h': handle, 'd': 1});
          return 0;
        }
        final ph = publicHandles[handle] ??=
            'P${(_counter++).toString().padLeft(7, '0')}';
        actions.add({'a': 'ph', 'h': handle, 'ph': ph});
        return ph;
    }
    return -2; // EARGS
  }

  /// `cr`: [общие папки, узлы, тройки (папка, узел, ключ)].
  void _applyReaderKeys(List cr, String Function(String ref) resolve) {
    final shares = (cr[0] as List).cast<String>();
    final refs = (cr[1] as List).cast<String>();
    final triples = cr[2] as List;
    for (var i = 0; i < triples.length; i += 3) {
      final node = resolve(refs[triples[i + 1] as int]);
      (readerKeys[node] ??= {})[shares[triples[i] as int]] =
          triples[i + 2] as String;
    }
  }

  /// Команды читателя ссылки на папку (без сеанса).
  Object? _readerCommand(Map<String, dynamic> c, String link) {
    final folder = publicHandles.entries
        .where((e) => e.value == link && exported.contains(e.key))
        .firstOrNull
        ?.key;
    if (folder == null) return MegaApiException.eNoEnt;
    bool inside(String? handle) {
      for (
        var h = handle;
        h != null && h.isNotEmpty;
        h = nodes[h]?['p'] as String?
      ) {
        if (h == folder) return true;
      }
      return false;
    }

    switch (c['a']) {
      case 'f':
        return {
          'f': [
            for (final node in nodes.values)
              if (inside(node['h'] as String))
                {
                  ...node,
                  // Читатель видит только ключ для своей папки.
                  'k': switch (readerKeys[node['h']]?[folder]) {
                    final key? => '$folder:$key',
                    null => '',
                  },
                },
          ],
        };
      case 'g':
        final node = nodes[c['n']];
        if (node == null || !inside(c['n'] as String)) {
          return MegaApiException.eNoEnt;
        }
        return {'g': 'https://download.example/${c['n']}', 's': node['s']};
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

  group('публичные доски', () {
    MegaPublicReader readerOf(FakeMega server) =>
        MegaPublicReader(server.client, listingTtl: Duration.zero);

    test('адрес: ссылка на папку и имя файла', () {
      final link = MegaFolderLink(
        publicHandle: 'abcDEF12',
        shareKey: Uint8List.fromList(List.generate(16, (i) => i)),
        fileName: 'x.board',
      );
      expect(link.encode(), startsWith('https://mega.nz/folder/abcDEF12#'));
      final parsed = MegaFolderLink.parse(link.encode())!;
      expect(parsed.publicHandle, 'abcDEF12');
      expect(parsed.shareKey, link.shareKey);
      expect(parsed.fileName, 'x.board');
      expect(MegaFolderLink.parse('https://www.dropbox.com/scl/x'), isNull);
      expect(MegaFolderLink.parse('https://mega.nz/folder/abc#AAAA/x'), isNull);
      expect(MegaFolderLink.parse('https://mega.nz/folder/abc#AAAA'), isNull);
    });

    test('ключ папки одинаков на всех устройствах и разный у папок', () async {
      final master = credentials().masterKey;
      final a = await MegaFolderLink.deriveShareKey(master, 'FOLDER01');
      expect(await MegaFolderLink.deriveShareKey(master, 'FOLDER01'), a);
      expect(a, hasLength(16));
      expect(await MegaFolderLink.deriveShareKey(master, 'FOLDER02'), isNot(a));
    });

    test('ссылка на папку переживает перезапись файла', () async {
      final server = FakeMega();
      final storage = storageOn(server);
      await storage.upload('v/board/m.board', bytesOf(10));
      final locator = await storage.publish('v/board/m.board');
      final reader = readerOf(server);
      expect(await reader.download(locator), bytesOf(10));

      // MEGA при перезаписи создаёт новый узел — ссылка на папку та же.
      await storage.upload('v/board/m.board', bytesOf(30));
      expect(await reader.download(locator), bytesOf(30));
      expect(await storage.publish('v/board/m.board'), locator);
      expect(server.commands.where((c) => c == 's2'), hasLength(1));
    });

    test(
      'второе устройство узнаёт о ссылке и даёт читателю ключи новых файлов',
      () async {
        final server = FakeMega();
        final phone = storageOn(server);
        final laptop = storageOn(server);
        await phone.upload('v/files/a.bin', bytesOf(5));
        // Ноутбук загрузил дерево, когда ссылки ещё не было.
        expect(await laptop.listFiles('v/files'), hasLength(1));
        final first = MegaFolderLink.parse(
          await phone.publish('v/files/a.bin'),
        )!;

        await laptop.upload('v/files/b.bin', bytesOf(7));
        final second = MegaFolderLink(
          publicHandle: first.publicHandle,
          shareKey: first.shareKey,
          fileName: 'b.bin',
        ).encode();
        // Ключ для читателя ушёл вместе с загрузкой, до publish.
        expect(await readerOf(server).download(second), bytesOf(7));
        expect(await laptop.publish('v/files/b.bin'), second);
      },
    );

    test('закрытая ссылка не читается, новая — другая', () async {
      final server = FakeMega();
      final storage = storageOn(server);
      await storage.upload('v/board/m.board', bytesOf(10));
      final locator = await storage.publish('v/board/m.board');

      await storage.unpublish('v/board/m.board', locator);
      await storage.unpublish('v/board/m.board', locator);
      expect(server.exported, isEmpty);
      expect(server.publicHandles, isEmpty);
      await expectLater(
        readerOf(server).download(locator),
        throwsA(isA<StorageNotFoundException>()),
      );

      final reopened = await storage.publish('v/board/m.board');
      expect(reopened, isNot(locator));
      await expectLater(
        readerOf(server).download(locator),
        throwsA(isA<StorageNotFoundException>()),
      );
    });

    test('доска на MEGA: читатель видит записи и файлы, закрытие', () async {
      final server = FakeMega();
      final storage = storageOn(server);
      final encryptionKey = List<int>.generate(32, (i) => i + 9);
      final signer = await BoardSigner.fromSeed(List<int>.filled(32, 3));
      final repository = EncryptedCloudPostRepository(
        storage: storage,
        vaultId: 'vault1',
        cipher: AesGcmCipher(encryptionKey),
        deviceName: 'Телефон',
      );
      final publisher = BoardPublisher(
        storage: storage,
        sharing: storage,
        vaultId: 'vault1',
        cipher: AesGcmCipher(encryptionKey),
        encryptionKey: encryptionKey,
        signer: signer,
        provider: CloudProviderId.mega,
        loadPosts: repository.fetchPosts,
      );
      final reader = readerOf(server);
      Future<BoardSnapshot> read(ReaderKey key) async =>
          BoardManifestCodec(AesGcmCipher(key.encryptionKey)).decode(
            await reader.download(key.locator),
            BoardVerifier(key.ownerPublicKey),
          );

      await repository.sendText('первая');
      final file = await repository.sendFile(
        fileName: 'фото.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final key = await publisher.open(label: 'Доска');
      expect(key.provider, CloudProviderId.mega);
      var board = await read(key);
      expect(board.posts, hasLength(2));
      final encrypted = await reader.download(
        board.fileLocators[file.attachment!.id]!,
      );
      expect(await AesGcmCipher(encryptionKey).decrypt(encrypted), [1, 2, 3]);

      // Опись перезаписывается — ключ читателя тот же.
      await repository.sendText('вторая');
      await publisher.sync(await repository.fetchPosts());
      board = await read(key);
      expect(board.posts.map((p) => p.text), contains('вторая'));

      await publisher.close();
      await expectLater(
        reader.download(key.locator),
        throwsA(isA<StorageNotFoundException>()),
      );
      await expectLater(
        reader.download(board.fileLocators[file.attachment!.id]!),
        throwsA(isA<StorageNotFoundException>()),
      );
      expect(server.exported, isEmpty);
    });
  });
}
