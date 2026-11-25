import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/storage/cloud_connection_service.dart';
import 'package:transmitter/core/storage/cloud_provider_adapter.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/providers/p2p/p2p_adapter.dart';
import 'package:transmitter/core/storage/providers/p2p/p2p_storage_io.dart';

void main() {
  group('CloudProviderId.p2p', () {
    test('имеет правильный код и свойства', () {
      expect(CloudProviderId.p2p.code, 'p2p');
      expect(CloudProviderId.p2p.isCloud, isFalse);
      expect(CloudProviderId.fromCode('p2p'), CloudProviderId.p2p);
    });
  });

  group('IoP2pStorage', () {
    late Directory tempDir;
    late IoP2pStorage storage;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('transmitter_p2p_test_');
      storage = IoP2pStorage(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('создание папок и листинг пустой директории', () async {
      await storage.ensureFolder('sub/folder');
      expect(await storage.listFiles('sub/folder'), isEmpty);
      expect(await storage.listFolders('sub'), ['folder']);
    });

    test('загрузка и скачивание байт с колбэком прогресса', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      int? progressCount;
      int? progressTotal;

      await storage.upload(
        'posts/test.bin',
        bytes,
        onProgress: (count, total) {
          progressCount = count;
          progressTotal = total;
        },
      );

      expect(progressCount, 5);
      expect(progressTotal, 5);

      final files = await storage.listFiles('posts');
      expect(files.length, 1);
      expect(files.first.name, 'test.bin');
      expect(files.first.size, 5);

      final downloaded = await storage.download('posts/test.bin');
      expect(downloaded, bytes);
    });

    test('потоковая загрузка и потоковое скачивание', () async {
      final data = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final stream = Stream.value(data);

      await storage.uploadStream('stream_test.bin', stream, length: data.length);

      final downloadedStream = storage.downloadStream('stream_test.bin');
      final chunks = await downloadedStream.toList();
      final result = Uint8List.fromList(chunks.expand((c) => c).toList());

      expect(result, data);
    });

    test('удаление файлов и директорий', () async {
      await storage.upload('test/a.txt', Uint8List.fromList([1, 2]));
      expect(await storage.listFiles('test'), hasLength(1));

      await storage.delete('test/a.txt');
      expect(await storage.listFiles('test'), isEmpty);

      // Удаление несуществующего пути не вызывает исключений
      await storage.delete('test/non_existent.txt');
    });

    test('переименование папок', () async {
      await storage.upload('old_dir/a.txt', Uint8List.fromList([10, 20]));
      await storage.renameFolder('old_dir', 'new_dir');

      expect(await storage.listFiles('old_dir'), isEmpty);
      final newFiles = await storage.listFiles('new_dir');
      expect(newFiles.length, 1);
      expect(newFiles.first.name, 'a.txt');
    });

    test('скачивание несуществующего файла бросает StorageNotFoundException', () {
      expect(
        () => storage.download('missing.txt'),
        throwsA(isA<StorageNotFoundException>()),
      );
      expect(
        () => storage.downloadStream('missing.txt').toList(),
        throwsA(isA<StorageNotFoundException>()),
      );
    });
  });

  group('P2pAdapter & CloudConnectionService', () {
    test('P2P адаптер всегда настроен и предоставляет локальное хранилище без входа', () async {
      final tempDir = Directory.systemTemp.createTempSync('p2p_adapter_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final storage = IoP2pStorage(tempDir);
      final adapter = P2pAdapter(storage: storage);

      expect(adapter.id, CloudProviderId.p2p);
      expect(adapter.isConfigured, isTrue);
      expect(await adapter.signIn(), isNotEmpty);

      final registry = CloudProviderRegistry([adapter]);
      final service = CloudConnectionService(registry, InMemoryKeyValueStore());

      expect(service.isSupported(CloudProviderId.p2p), isTrue);
      expect(service.isConnected(CloudProviderId.p2p), isTrue);

      final acquiredStorage = service.storageFor(CloudProviderId.p2p);
      expect(acquiredStorage, same(storage));
    });
  });
}
