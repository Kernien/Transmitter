import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/persistence/file_key_value_store.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('transmitter_store');
    file = File('${dir.path}/app/secure_store.json');
  });
  tearDown(() => dir.delete(recursive: true));

  FileKeyValueStore store() => FileKeyValueStore(file);

  test('запись, чтение и удаление сохраняются между запусками', () async {
    final first = store();
    expect(await first.read('a'), isNull);
    await first.write('a', '1');
    await first.write('b', 'два');
    await first.delete('a');

    final second = store();
    expect(await second.read('a'), isNull);
    expect(await second.read('b'), 'два');
    expect(file.existsSync(), isTrue);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('одновременные записи не теряются', () async {
    final s = store();
    await Future.wait([for (var i = 0; i < 20; i++) s.write('k$i', '$i')]);
    final reopened = store();
    for (var i = 0; i < 20; i++) {
      expect(await reopened.read('k$i'), '$i');
    }
  });

  test('повреждённый файл откладывается, приложение запускается', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{не json');
    final s = store();
    expect(await s.read('a'), isNull);
    expect(File('${file.path}.broken').existsSync(), isTrue);
    await s.write('a', '1');
    expect(await store().read('a'), '1');
  });

  test('файл доступен только владельцу', () async {
    await store().write('a', '1');
    final mode = (await file.stat()).mode & 0x1FF;
    final dirMode = (await file.parent.stat()).mode & 0x1FF;
    expect(mode, 0x180, reason: 'файл 600'); // rw-------
    expect(dirMode, 0x1C0, reason: 'папка 700'); // rwx------
  }, skip: Platform.isWindows ? 'права доступа Unix' : false);
}
