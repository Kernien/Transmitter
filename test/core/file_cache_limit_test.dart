import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/app/cache_settings.dart';
import 'package:transmitter/core/persistence/blob_cache.dart';
import 'package:transmitter/core/persistence/file_blob_cache.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';

void main() {
  late Directory dir;
  late FileBlobCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('transmitter_limit');
    cache = FileBlobCache(dir);
  });
  tearDown(() => dir.delete(recursive: true));

  /// Даём фоновой уборке закончиться.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  Future<void> putFile(
    BlobCache scope,
    String id,
    int size,
    DateTime opened,
  ) async {
    await scope.write(attachmentCacheKey(id), List<int>.filled(size, 1));
    await File(
      '${(scope as FileBlobCache).directory.path}/${attachmentCacheKey(id)}',
    ).setLastModified(opened);
  }

  test('сверх лимита первыми уходят давно не открытые файлы', () async {
    final a = cache.scope('dropbox-a');
    final b = cache.scope('board-b');
    cache.limitBytes = 1 << 30; // пока без ограничений
    await putFile(a, 'old', 400, DateTime(2026, 1, 1));
    await putFile(b, 'mid', 400, DateTime(2026, 2, 1));
    await putFile(a, 'new', 400, DateTime(2026, 3, 1));
    // Записи (не файлы) лимит не трогает.
    await a.write('index.json', List<int>.filled(500, 1));
    await settle();

    cache.limitBytes = 900;
    await settle();
    expect(await a.read(attachmentCacheKey('old')), isNull);
    expect(await b.read(attachmentCacheKey('mid')), isNotNull);
    expect(await a.read(attachmentCacheKey('new')), isNotNull);
    expect(await a.read('index.json'), isNotNull);
  });

  test('открытый файл считается свежим', () async {
    final a = cache.scope('dropbox-a');
    cache.limitBytes = 1 << 30;
    await putFile(a, 'first', 400, DateTime(2026, 1, 1));
    await putFile(a, 'second', 400, DateTime(2026, 2, 1));
    await a.read(attachmentCacheKey('first')); // открыли — теперь свежий
    cache.limitBytes = 500;
    await settle();
    expect(await a.read(attachmentCacheKey('first')), isNotNull);
    expect(await a.read(attachmentCacheKey('second')), isNull);
  });

  test('«Место на устройстве»: объём, лимит, очистка', () async {
    final store = InMemoryKeyValueStore();
    final settings = CacheSettings(cache, store);
    final a = cache.scope('dropbox-a');
    await a.write(attachmentCacheKey('x'), List<int>.filled(1000, 1));
    await a.write('index.json', List<int>.filled(10, 1));
    await settle();

    expect(settings.isAvailable, isTrue);
    expect(await settings.usedBytes(), 1010);

    await settings.setLimit(CacheSettings.limitOptions.first);
    final reloaded = FileBlobCache(dir);
    await CacheSettings(reloaded, store).load();
    expect(reloaded.limitBytes, CacheSettings.limitOptions.first);

    await settings.clearFiles();
    expect(await settings.usedBytes(), 10, reason: 'записи остались');
  });

  test('в браузере настройки нет', () {
    expect(
      CacheSettings(const NoBlobCache(), InMemoryKeyValueStore()).isAvailable,
      isFalse,
    );
  });
}
