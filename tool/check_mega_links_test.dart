// Проверка для публичных досок в MEGA: читается ли файл по публичной ссылке
// без входа (из приложения и из браузера — CORS) и остаётся ли ссылка
// рабочей, когда файл перезаписывают (опись доски перезаписывается при
// каждом изменении ленты).
//
// Запуск из папки проекта (пароль — только в переменных окружения):
//   $env:MEGA_EMAIL = '...'; $env:MEGA_PASSWORD = '...'
//   $env:MEGA_2FA = '123456'   # если включена двухфакторная защита
//   flutter test tool/check_mega_links_test.dart
//
// Тестовые файлы создаются в корне облачного диска и в конце удаляются.
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member — консольная утилита.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/providers/mega/mega_aes.dart';
import 'package:transmitter/core/storage/providers/mega/mega_api.dart';
import 'package:transmitter/core/storage/providers/mega/mega_crypto.dart';
import 'package:transmitter/core/storage/providers/mega/mega_public_reader.dart';
import 'package:transmitter/core/storage/providers/mega/mega_session.dart';
import 'package:transmitter/core/storage/providers/mega/mega_storage.dart';

const webOrigin = 'https://kernien.github.io';

/// Отчёт дублируется в файл (без паролей и ключей), чтобы его можно было
/// прочитать, не копируя вывод терминала.
const reportPath = 'build/mega_links_check.txt';
final _report = StringBuffer();

void say(String line) {
  print(line);
  _report.writeln(line);
}

/// Поля объекта без секретов: длинные строки (ключи) скрыты.
Map<Object?, Object?> _mask(Map<Object?, Object?> map) => {
  for (final MapEntry(:key, :value) in map.entries)
    key: value is String && value.length > 11
        ? '<${value.length} симв.>'
        : value is Map || value is List
        ? '<${value.runtimeType}>'
        : value,
};

/// Для кого есть ключ узла: «пользователь:…/папка:…» → «пользователь/папка».
String _keyOwners(Object? key) => key is String
    ? key.split('/').map((part) => part.split(':').first).join(' + ')
    : '—';

void _saveReport() {
  File(reportPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(_report.toString());
  print('\nОтчёт сохранён: $reportPath');
}

void main() {
  final env = Platform.environment;
  final email = env['MEGA_EMAIL'];
  final password = env['MEGA_PASSWORD'];
  // Первые две проверки — разведка протокола (выбор ссылки на папку);
  // по умолчанию идёт только проверка кода приложения.
  final exploratory = env['MEGA_PROBE_ALL'] != null;

  test(
    'MEGA: публичные ссылки',
    () async {
      final client = http.Client();
      final results = <String, bool>{};
      final cleanup = <String>[];
      final MegaCredentials credentials;
      try {
        credentials = await MegaAuthenticator(client).signIn(
          email: email!,
          password: password!,
          secondFactorCode: env['MEGA_2FA'],
        );
      } catch (e) {
        say('Вход не удался: $e');
        _saveReport();
        rethrow;
      }
      final api = MegaApi(client, sid: credentials.sessionId);
      final master = MegaAes(credentials.masterKey);
      final public = MegaApi(client);

      try {
        final tree = await api.call({'a': 'f', 'c': 1}) as Map;
        final root = [
          for (final n in tree['f'] as List)
            if ((n as Map)['t'] == 2) n['h'] as String,
        ].single;

        Future<({String handle, Uint8List key})> upload(
          String name,
          List<int> content, {
          String? oldVersion,
        }) async {
          final bytes = Uint8List.fromList(content);
          final key = MegaCrypto.randomBytes(16);
          final nonce = MegaCrypto.randomBytes(8);
          final encrypted = MegaCrypto.encryptFile(bytes, key, nonce);
          final target = await api.call({
            'a': 'u',
            's': bytes.length,
            'ssl': 2,
            'v': 2,
            'ms': 0,
            'r': 0,
            'e': 0,
          }) as Map;
          final completion = await api.uploadChunk(
            target['p'] as String,
            0,
            encrypted.data,
          );
          final fileKey = MegaCrypto.packFileKey(key, nonce, encrypted.mac);
          final result = await api.call({
            'a': 'p',
            't': root,
            'n': [
              {
                'h': MegaCrypto.b64(completion),
                't': 0,
                'a': MegaCrypto.encryptAttributes({'n': name}, key),
                'k': MegaCrypto.b64(master.encryptEcb(fileKey)),
                'ov': ?oldVersion,
              },
            ],
          }) as Map;
          final handle = ((result['f'] as List).first as Map)['h'] as String;
          cleanup.add(handle);
          return (handle: handle, key: fileKey);
        }

        Future<String> export(String handle) async =>
            await api.call({'a': 'l', 'n': handle}) as String;

        /// Что отдаёт публичная ссылка: содержимое или код ошибки.
        Future<String> readPublic(String ph, Uint8List key) async {
          try {
            final info =
                await public.call({'a': 'g', 'g': 1, 'ssl': 2, 'p': ph}) as Map;
            if (info['e'] is int) return 'ошибка ${info['e']}';
            final data = await public.downloadBytes(info['g'] as String);
            final plain = MegaCrypto.decryptFile(
              data,
              MegaCrypto.fileAesKey(key),
              Uint8List.sublistView(key, 16, 24),
              Uint8List.sublistView(key, 24, 32),
            );
            return plain == null ? 'не расшифровано' : utf8.decode(plain);
          } on MegaApiException catch (e) {
            return 'ошибка ${e.code}';
          }
        }

        final stamp = DateTime.now().millisecondsSinceEpoch;

        say('\n== Ссылка на файл');
        final a1 = await upload('probe-$stamp-a.bin', utf8.encode('v1'));
        final phA = await export(a1.handle);
        say('ссылка: https://mega.nz/file/$phA#…');
        final readA = await readPublic(phA, a1.key);
        say('без входа: $readA');
        results['чтение по ссылке без входа'] = readA == 'v1';
        results['повторный export даёт ту же ссылку'] =
            await export(a1.handle) == phA;

        say('\n== CORS (браузер)');
        final cs = await client.post(
          Uri.parse('${MegaApi.defaultGateway}cs?id=1'),
          headers: {'Origin': webOrigin, 'Content-Type': 'application/json'},
          body: jsonEncode([
            {'a': 'g', 'g': 1, 'ssl': 2, 'p': phA},
          ]),
        );
        final csCors = cs.headers['access-control-allow-origin'];
        say('API: Access-Control-Allow-Origin = $csCors');
        results['CORS: API'] = csCors == '*' || csCors == webOrigin;
        final url = ((jsonDecode(cs.body) as List).first as Map)['g'] as String;
        final file = await client.get(
          Uri.parse(url),
          headers: {'Origin': webOrigin},
        );
        final fileCors = file.headers['access-control-allow-origin'];
        say('файл: Access-Control-Allow-Origin = $fileCors');
        results['CORS: скачивание'] = fileCors == '*' || fileCors == webOrigin;

        say('\n== Перезапись: новый узел, старый удалён (как сейчас)');
        final b1 = await upload('probe-$stamp-b.bin', utf8.encode('v1'));
        final phB = await export(b1.handle);
        final b2 = await upload('probe-$stamp-b.bin', utf8.encode('v2'));
        await api.call({'a': 'd', 'n': b1.handle});
        final readB = await readPublic(phB, b1.key);
        say('старая ссылка: $readB');
        results['ссылка переживает перезапись без версий'] = readB == 'v2';
        say('ссылка у нового узла: ${await export(b2.handle) == phB}');

        say('\n== Перезапись новой версией (ov)');
        final c1 = await upload('probe-$stamp-c.bin', utf8.encode('v1'));
        final phC = await export(c1.handle);
        final c2 = await upload(
          'probe-$stamp-c.bin',
          utf8.encode('v2'),
          oldVersion: c1.handle,
        );
        final readC = await readPublic(phC, c1.key);
        final readC2 = await readPublic(phC, c2.key);
        say('старая ссылка, старый ключ: $readC; новый ключ: $readC2');
        final phC2 = await export(c2.handle);
        say('ссылка у новой версии: ${phC2 == phC ? 'та же' : 'другая'}');
        results['новая версия (ov) сохраняет ссылку'] =
            readC2 == 'v2' || phC2 == phC;
        // Старая версия удаляется — жива ли ссылка?
        try {
          await api.call({'a': 'd', 'n': c1.handle});
        } on MegaApiException catch (e) {
          say('удаление старой версии: ошибка ${e.code}');
        }
        final readC3 = await readPublic(phC2, c2.key);
        say('после удаления старой версии: $readC3');
        results['ссылка новой версии после удаления старой'] = readC3 == 'v2';

        say('\n== Закрытие ссылки');
        await api.call({'a': 'l', 'n': a1.handle, 'd': 1});
        final closed = await readPublic(phA, a1.key);
        say('после закрытия: $closed');
        results['закрытая ссылка не читается'] = closed.startsWith('ошибка');
      } catch (e) {
        say("Ошибка проверки: $e");
        rethrow;
      } finally {
        for (final handle in cleanup) {
          try {
            await api.call({'a': 'd', 'n': handle});
          } on MegaApiException {
            // Уже удалён.
          }
        }
        say('\n==== Итог ====');
        results.forEach((name, ok) => say('${ok ? 'OK  ' : 'НЕТ '} $name'));
        _saveReport();
        client.close();
      }
    },
    skip: email == null || password == null
        ? 'нужны MEGA_EMAIL и MEGA_PASSWORD'
        : exploratory
        ? false
        : 'разведка уже сделана (MEGA_PROBE_ALL=1 — повторить)',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  // Ссылка на папку постоянна, а файлы в ней можно перезаписывать. Для этого
  // у папки появляется общий ключ (s2 + EXP), и ключ каждого нового файла в
  // ней передаётся ещё и зашифрованным этим ключом (cr) — как в megajs.
  test(
    'MEGA: ссылка на папку',
    () async {
      final client = http.Client();
      final results = <String, bool>{};
      final cleanup = <String>[];
      Future<MegaCredentials> signIn() => MegaAuthenticator(client).signIn(
        email: email!,
        password: password!,
        secondFactorCode: env['MEGA_2FA'],
      );
      final MegaCredentials credentials;
      final MegaCredentials second;
      try {
        credentials = await signIn();
        // Второе устройство того же аккаунта (двухфакторный код — тот же,
        // если не успел смениться).
        second = await signIn();
      } catch (e) {
        say('Вход не удался: $e');
        _saveReport();
        rethrow;
      }
      final api = MegaApi(client, sid: credentials.sessionId);
      final apiB = MegaApi(client, sid: second.sessionId);
      final master = MegaAes(credentials.masterKey);

      /// Команда от имени читателя ссылки на папку (`n` — её дескриптор).
      Future<Object?> asReader(String ph, Map<String, Object?> command) async {
        final response = await client.post(
          Uri.parse('${MegaApi.defaultGateway}cs')
              .replace(queryParameters: {'id': '1', 'n': ph}),
          headers: {'Origin': webOrigin, 'Content-Type': 'application/json'},
          body: jsonEncode([command]),
        );
        final result = jsonDecode(response.body);
        return result is List ? result.first : result;
      }

      try {
        say('\n== Ссылка на папку');
        say('шаг: дерево');
        final tree = await api.call({'a': 'f', 'c': 1}) as Map;
        final root = [
          for (final n in tree['f'] as List)
            if ((n as Map)['t'] == 2) n['h'] as String,
        ].single;
        // Второе устройство уже загрузило дерево — до появления общего ключа.
        say('шаг: дерево второго устройства');
        final treeB = await apiB.call({'a': 'f', 'c': 1}) as Map;
        var snB = treeB['sn'] as String;

        final stamp = DateTime.now().millisecondsSinceEpoch;
        final folderKey = MegaCrypto.randomBytes(16);
        say('шаг: папка');
        final created = await api.call({
          'a': 'p',
          't': root,
          'n': [
            {
              'h': 'xxxxxxxx',
              't': 1,
              'a': MegaCrypto.encryptAttributes({
                'n': 'probe-$stamp',
              }, folderKey),
              'k': MegaCrypto.b64(master.encryptEcb(folderKey)),
            },
          ],
        }) as Map;
        final folder = ((created['f'] as List).first as Map)['h'] as String;
        cleanup.add(folder);

        Uint8List? shareKey;

        Future<({String handle, Uint8List key})> upload(
          String name,
          String content,
        ) async {
          final bytes = Uint8List.fromList(utf8.encode(content));
          final key = MegaCrypto.randomBytes(16);
          final nonce = MegaCrypto.randomBytes(8);
          final encrypted = MegaCrypto.encryptFile(bytes, key, nonce);
          final target = await api.call({
            'a': 'u',
            's': bytes.length,
            'ssl': 2,
            'v': 2,
            'ms': 0,
            'r': 0,
            'e': 0,
          }) as Map;
          final completion = MegaCrypto.b64(
            await api.uploadChunk(target['p'] as String, 0, encrypted.data),
          );
          final fileKey = MegaCrypto.packFileKey(key, nonce, encrypted.mac);
          final share = shareKey;
          final result = await api.call({
            'a': 'p',
            't': folder,
            'n': [
              {
                'h': completion,
                't': 0,
                'a': MegaCrypto.encryptAttributes({'n': name}, key),
                'k': MegaCrypto.b64(master.encryptEcb(fileKey)),
              },
            ],
            if (share != null)
              'cr': [
                [folder],
                [completion],
                [0, 0, MegaCrypto.b64(MegaAes(share).encryptEcb(fileKey))],
              ],
          }) as Map;
          final handle = ((result['f'] as List).first as Map)['h'] as String;
          return (handle: handle, key: fileKey);
        }

        say('шаг: файл в папке');
        final first = await upload('manifest.board', 'v1');

        // Общий ключ папки и ссылка.
        say('шаг: общий ключ (s2)');
        shareKey = MegaCrypto.randomBytes(16);
        final share = shareKey;
        final cr = [
          [folder],
          [folder, first.handle],
          [
            0,
            0,
            MegaCrypto.b64(MegaAes(share).encryptEcb(folderKey)),
            0,
            1,
            MegaCrypto.b64(MegaAes(share).encryptEcb(first.key)),
          ],
        ];
        final okKey = MegaCrypto.b64(master.encryptEcb(share));
        final haKey = MegaCrypto.b64(
          master.encryptEcb(Uint8List.fromList(ascii.encode('$folder$folder'))),
        );
        // Повторы EAGAIN — быстрые: здесь важно, какой вариант примут.
        final quick = MegaApi(
          client,
          sid: credentials.sessionId,
          retryDelay: const Duration(milliseconds: 200),
        );
        final exp = [
          {'u': 'EXP', 'r': 0},
        ];
        final variants = <String, Map<String, Object?>>{
          'ok+ha+cr (как megajs)': {
            'a': 's2',
            'n': folder,
            's': exp,
            'ok': okKey,
            'ha': haKey,
            'cr': cr,
          },
          'ok+cr': {'a': 's2', 'n': folder, 's': exp, 'ok': okKey, 'cr': cr},
          'cr': {'a': 's2', 'n': folder, 's': exp, 'cr': cr},
          'без ключей': {'a': 's2', 'n': folder, 's': exp},
        };
        String? accepted;
        for (final MapEntry(key: name, value: command) in variants.entries) {
          try {
            final result = await quick.call(command);
            say('s2 $name: принят ($result)');
            accepted = name;
            break;
          } on MegaApiException catch (e) {
            say('s2 $name: ошибка ${e.code}');
          }
        }
        results['общий ключ папки (s2) принят'] = accepted != null;
        if (accepted != 'ok+ha+cr (как megajs)' && accepted != 'ok+cr') {
          // Без cr сервер не знает ключей для читателя — дадим их отдельно.
          try {
            final result = await quick.call({'a': 'k', 'cr': cr});
            say('ключи для читателя (k+cr): принято ($result)');
          } on MegaApiException catch (e) {
            say('ключи для читателя (k+cr): ошибка ${e.code}');
          }
        }
        say('шаг: ссылка (l)');
        final String ph;
        try {
          ph = await quick.call({'a': 'l', 'n': folder}) as String;
        } on MegaApiException catch (e) {
          say('ссылка на папку: ошибка ${e.code}');
          rethrow;
        }
        say('ссылка: https://mega.nz/folder/$ph#…');

        /// Что читатель видит в папке: имя → содержимое.
        Future<Map<String, String>> readFolder() async {
          final listing = await asReader(ph, {
            'a': 'f',
            'c': 1,
            'ca': 1,
            'r': 1,
          });
          if (listing is! Map) return {'ошибка': '$listing'};
          final files = <String, String>{};
          for (final raw in listing['f'] as List) {
            final node = raw as Map;
            if (node['t'] != 0) continue;
            final keyPart = (node['k'] as String)
                .split('/')
                .firstWhere((p) => p.startsWith('$folder:'), orElse: () => '');
            if (keyPart.isEmpty) {
              files[node['h'] as String] = 'нет ключа для читателя';
              continue;
            }
            final key = MegaAes(shareKey!)
                .decryptEcb(MegaCrypto.unb64(keyPart.substring(9)));
            final name =
                MegaCrypto.decryptAttributes(
                      node['a'] as String,
                      MegaCrypto.fileAesKey(key),
                    )?['n']
                    as String? ??
                '?';
            final info = await asReader(ph, {
              'a': 'g',
              'g': 1,
              'ssl': 2,
              'n': node['h'],
            });
            if (info is! Map || info['g'] is! String) {
              files[name] = 'нет адреса: $info';
              continue;
            }
            final data = await client.get(
              Uri.parse(info['g'] as String),
              headers: {'Origin': webOrigin},
            );
            final plain = MegaCrypto.decryptFile(
              data.bodyBytes,
              MegaCrypto.fileAesKey(key),
              Uint8List.sublistView(key, 16, 24),
              Uint8List.sublistView(key, 24, 32),
            );
            files[name] = plain == null
                ? 'не расшифровано'
                : utf8.decode(plain);
          }
          return files;
        }

        say('шаг: чтение папки по ссылке');
        final before = await readFolder();
        say('читатель видит: $before');
        results['папка: файл читается по ссылке'] =
            before['manifest.board'] == 'v1';

        // Перезапись: новый узел с ключом для читателя, старый удаляется.
        say('шаг: перезапись в общей папке');
        await upload('manifest.board', 'v2');
        await api.call({'a': 'd', 'n': first.handle});
        final after = await readFolder();
        say('после перезаписи: $after');
        results['папка: та же ссылка показывает новую версию'] =
            after.length == 1 && after['manifest.board'] == 'v2';

        say('\n== Второе устройство узнаёт об общем ключе');
        final actions = <String>[];
        var hasShareKey = false;
        for (var i = 0; i < 10; i++) {
          final response = await apiB.poll(snB);
          snB = response['sn'] as String? ?? snB;
          for (final action in response['a'] as List? ?? const []) {
            final a = action as Map;
            actions.add('${a['a']}${a.containsKey('ok') ? '(ok)' : ''}');
            if (a['a'] == 's' || a['a'] == 'ph') {
              say('  ${a['a']}: ${_mask(a)}');
            }
            if (a['a'] == 't') {
              for (final node in (a['t'] as Map?)?['f'] as List? ?? const []) {
                final n = node as Map;
                if (n['h'] == folder || n['p'] == folder) {
                  say(
                    '  t: узел ${n['h']} (тип ${n['t']}), '
                    'ключи для: ${_keyOwners(n['k'])}',
                  );
                }
              }
            }
            if (a['ok'] != null || a['k'] != null && a['n'] == folder) {
              hasShareKey = true;
            }
          }
          if (response.containsKey('w')) break;
        }
        say('события /sc: $actions');
        results['второе устройство получает ключ из /sc'] = hasShareKey;
        final reloaded = await apiB.call({'a': 'f', 'c': 1}) as Map;
        say('новое дерево, поля ответа: ${reloaded.keys.toList()}');
        for (final node in reloaded['f'] as List) {
          final n = node as Map;
          if (n['h'] == folder || n['p'] == folder) {
            say(
              '  узел ${n['h']} (тип ${n['t']}), ключи для: '
              '${_keyOwners(n['k'])}, поля: ${n.keys.toList()}',
            );
          }
        }
        for (final field in ['s', 'ps', 'ph']) {
          for (final entry in reloaded[field] as List? ?? const []) {
            if (entry is Map &&
                (entry['h'] == folder || entry['n'] == folder)) {
              say('  $field: ${_mask(entry)}');
            }
          }
        }
        final ok = [
          for (final entry in reloaded['ok'] as List? ?? const [])
            if ((entry as Map)['h'] == folder) entry,
        ];
        say('в новом дереве (ok): ${ok.isEmpty ? 'нет' : 'есть'}');
        final shared =
            ok.isNotEmpty &&
            listEquals(
              MegaAes(second.masterKey)
                  .decryptEcb(MegaCrypto.unb64(ok.first['k'] as String)),
              shareKey,
            );
        results['второе устройство получает ключ из дерева'] = shared;

        say('\n== Закрытие ссылки на папку');
        await api.call({'a': 'l', 'n': folder, 'd': 1});
        await api.call({
          'a': 's2',
          'n': folder,
          's': [
            {'u': 'EXP', 'r': ''},
          ],
        });
        final closed = await asReader(ph, {'a': 'f', 'c': 1, 'ca': 1, 'r': 1});
        say('после закрытия: ${closed is Map ? 'папка видна' : closed}');
        results['закрытая ссылка на папку не читается'] = closed is! Map;
      } catch (e) {
        say('Ошибка проверки: $e');
        rethrow;
      } finally {
        for (final handle in cleanup) {
          try {
            await api.call({'a': 'd', 'n': handle});
          } on MegaApiException {
            // Уже удалён.
          }
        }
        say('\n==== Итог (папка) ====');
        results.forEach((name, ok) => say('${ok ? 'OK  ' : 'НЕТ '} $name'));
        _saveReport();
        client.close();
      }
    },
    skip: email == null || password == null
        ? 'нужны MEGA_EMAIL и MEGA_PASSWORD'
        : exploratory
        ? false
        : 'разведка уже сделана (MEGA_PROBE_ALL=1 — повторить)',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  // То же, что делает приложение: MegaStorage (владелец, два устройства) и
  // MegaPublicReader (читатель без входа).
  test(
    'MEGA: публичная доска кодом приложения',
    () async {
      final client = http.Client();
      final results = <String, bool>{};
      final MegaCredentials phoneSession;
      final MegaCredentials laptopSession;
      try {
        phoneSession = await MegaAuthenticator(client).signIn(
          email: email!,
          password: password!,
          secondFactorCode: env['MEGA_2FA'],
        );
        laptopSession = await MegaAuthenticator(client).signIn(
          email: email,
          password: password,
          secondFactorCode: env['MEGA_2FA'],
        );
      } catch (e) {
        say('Вход не удался: $e');
        _saveReport();
        rethrow;
      }
      final phone = MegaStorage(
        api: MegaApi(client),
        credentials: phoneSession,
        pollInterval: Duration.zero,
      );
      final laptop = MegaStorage(
        api: MegaApi(client),
        credentials: laptopSession,
        pollInterval: Duration.zero,
      );
      final reader = MegaPublicReader(client, listingTtl: Duration.zero);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final dir = 'probe-$stamp';

      Future<String> read(String locator) async {
        try {
          return utf8.decode(await reader.download(locator));
        } on StorageNotFoundException {
          return 'нет доступа';
        }
      }

      try {
        say('\n== Доска кодом приложения');
        await phone.upload('$dir/board/m.board', utf8.encode('опись 1'));
        // Ноутбук загрузил дерево до появления ссылки.
        await laptop.listFiles('$dir/board');
        final locator = await phone.publish('$dir/board/m.board');
        say('ссылка: ${locator.split('#').first}#…');
        final first = await read(locator);
        say('читатель: $first');
        results['читатель видит опись'] = first == 'опись 1';

        await phone.upload('$dir/board/m.board', utf8.encode('опись 2'));
        final second = await read(locator);
        say('после перезаписи: $second');
        results['та же ссылка после перезаписи'] = second == 'опись 2';

        await laptop.upload('$dir/board/m.board', utf8.encode('опись 3'));
        final third = await read(locator);
        say('после записи со второго устройства: $third');
        results['второе устройство пишет в открытую папку'] =
            third == 'опись 3';
        results['второе устройство даёт тот же адрес'] =
            await laptop.publish('$dir/board/m.board') == locator;

        await laptop.unpublish('$dir/board/m.board', locator);
        final closed = await read(locator);
        say('после закрытия со второго устройства: $closed');
        results['закрытая ссылка не читается'] = closed == 'нет доступа';
        final reopened = await phone.publish('$dir/board/m.board');
        results['повторное открытие — новая ссылка'] = reopened != locator;
        results['старая ссылка не оживает'] =
            await read(locator) == 'нет доступа';
        await phone.unpublish('$dir/board/m.board', reopened);
      } catch (e) {
        say('Ошибка проверки: $e');
        rethrow;
      } finally {
        // Убираем папку проверки целиком.
        try {
          final api = MegaApi(client, sid: phoneSession.sessionId);
          final master = MegaAes(phoneSession.masterKey);
          final tree = await api.call({'a': 'f', 'c': 1}) as Map;
          for (final raw in tree['f'] as List) {
            final node = raw as Map;
            if (node['t'] != 1) continue;
            final part = (node['k'] as String?)
                ?.split('/')
                .firstWhere(
                  (p) => p.startsWith('${phoneSession.userHandle}:'),
                  orElse: () => '',
                );
            if (part == null || part.isEmpty) continue;
            final key = master.decryptEcb(
              MegaCrypto.unb64(part.substring(part.indexOf(':') + 1)),
            );
            final name = MegaCrypto.decryptAttributes(
              node['a'] as String,
              MegaCrypto.fileAesKey(key),
            )?['n'];
            // И папки, оставшиеся от прерванных запусков.
            if (name is String && RegExp(r'^probe-\d+$').hasMatch(name)) {
              await api.call({'a': 'd', 'n': node['h']});
              say('убрана папка $name');
            }
          }
        } catch (e) {
          say('Не удалось убрать папку $dir: $e');
        }
        say('\n==== Итог (приложение) ====');
        results.forEach((name, ok) => say('${ok ? 'OK  ' : 'НЕТ '} $name'));
        _saveReport();
        client.close();
      }
    },
    skip: email == null || password == null
        ? 'нужны MEGA_EMAIL и MEGA_PASSWORD'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
