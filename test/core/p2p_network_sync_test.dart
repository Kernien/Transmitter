import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/p2p/p2p_protocol.dart';
import 'package:transmitter/core/p2p/p2p_sync_engine.dart';
import 'package:transmitter/core/p2p/platform_p2p_sync.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/providers/p2p/p2p_storage_io.dart';
import 'package:transmitter/core/vault/vault_key.dart';

void main() {
  group('P2P Network Sync (TCP + Discovery)', () {
    late Directory dirA;
    late Directory dirB;
    late IoP2pStorage storageA;
    late IoP2pStorage storageB;
    late IoP2pSyncService syncServiceA;
    late IoP2pSyncService syncServiceB;

    final key = VaultKey(
      secret: List<int>.generate(32, (i) => i + 1),
      provider: CloudProviderId.p2p,
      label: 'Тестовая P2P доска',
    );

    setUp(() {
      dirA = Directory.systemTemp.createTempSync('p2p_sync_test_a_');
      dirB = Directory.systemTemp.createTempSync('p2p_sync_test_b_');
      storageA = IoP2pStorage(dirA);
      storageB = IoP2pStorage(dirB);

      syncServiceA = IoP2pSyncService(storage: storageA, peerId: 'peer_aaa');
      syncServiceB = IoP2pSyncService(storage: storageB, peerId: 'peer_bbb');
    });

    tearDown(() async {
      syncServiceA.dispose();
      syncServiceB.dispose();
      if (dirA.existsSync()) dirA.deleteSync(recursive: true);
      if (dirB.existsSync()) dirB.deleteSync(recursive: true);
    });

    test('двусторонняя синхронизация постов и файлов между двумя узлами', () async {
      final portB = await syncServiceB.start();
      await syncServiceA.start();

      final hashA = await syncServiceA.registerBoard(key);
      final hashB = await syncServiceB.registerBoard(key);
      expect(hashA, hashB);

      final entryA = syncServiceA.boardEntryByHash(hashA)!;
      final entryB = syncServiceB.boardEntryByHash(hashB)!;
      expect(entryA.vaultFolder, entryB.vaultFolder);

      final vaultFolder = entryA.vaultFolder;

      // 1. Узел A создает пост и вложение
      await storageA.upload('$vaultFolder/posts/1000_postA.post', Uint8List.fromList([1, 2, 3]));
      await storageA.upload('$vaultFolder/files/attachmentA.bin', Uint8List.fromList([4, 5, 6, 7]));

      // 2. Узел B создает свой пост
      await storageB.upload('$vaultFolder/posts/2000_postB.post', Uint8List.fromList([8, 9, 10]));

      // 3. Узел A инициирует синхронизацию с B (peer_aaa < peer_bbb)
      final peerB = DiscoveredPeer(
        peerId: 'peer_bbb',
        address: '127.0.0.1',
        tcpPort: portB,
        matchingHashes: [hashA],
      );

      var syncedAtA = false;
      var syncedAtB = false;

      syncServiceA.onBoardSynced.listen((f) {
        if (f == vaultFolder) syncedAtA = true;
      });
      syncServiceB.onBoardSynced.listen((f) {
        if (f == vaultFolder) syncedAtB = true;
      });

      await syncServiceA.syncWithPeer(peerB);

      // Проверяем: узел A получил пост от B!
      final postsAtA = await storageA.listFiles('$vaultFolder/posts');
      final namesAtA = postsAtA.map((p) => p.name).toSet();
      expect(namesAtA, contains('1000_postA.post'));
      expect(namesAtA, contains('2000_postB.post'));
      expect(syncedAtA, isTrue);

      // Проверяем: узел B получил пост и файл от A!
      final postsAtB = await storageB.listFiles('$vaultFolder/posts');
      final namesAtB = postsAtB.map((p) => p.name).toSet();
      expect(namesAtB, contains('1000_postA.post'));
      expect(namesAtB, contains('2000_postB.post'));

      final filesAtB = await storageB.listFiles('$vaultFolder/files');
      final fileNamesAtB = filesAtB.map((f) => f.name).toSet();
      expect(fileNamesAtB, contains('attachmentA.bin'));

      final downloadedContent = await storageB.download('$vaultFolder/files/attachmentA.bin');
      expect(downloadedContent, Uint8List.fromList([4, 5, 6, 7]));
      expect(syncedAtB, isTrue);
    });

    test('P2pProtocol вычисляет одинаковые хэши для одинаковых ключей', () {
      final hash1 = P2pProtocol.discoveryHash(key.secret);
      final hash2 = P2pProtocol.discoveryHash(List.from(key.secret));
      expect(hash1, hash2);

      final diffKey = List<int>.filled(32, 99);
      final hashDiff = P2pProtocol.discoveryHash(diffKey);
      expect(hashDiff, isNot(hash1));
    });

    test('P2pProtocol рукопожатие успешно проверяет HMAC доказательство', () {
      const nonce = 'random_test_nonce_123';
      final proof = P2pProtocol.computeAuthProof(key.secret, nonce);

      expect(P2pProtocol.verifyAuthProof(key.secret, nonce, proof), isTrue);
      expect(P2pProtocol.verifyAuthProof(key.secret, 'wrong_nonce', proof), isFalse);
      expect(
        P2pProtocol.verifyAuthProof(List.filled(32, 0), nonce, proof),
        isFalse,
      );
    });

    test('P2pSyncEngine регистрирует доски и отслеживает активных пиров', () async {
      final engine = P2pSyncEngine(
        storage: storageA,
        peerId: 'peer_engine',
        sync: syncServiceA,
      );

      await engine.registerVault(key);
      expect(engine.activePeersFor(key), 0);

      // Эмулируем обнаружение пира
      final hash = P2pProtocol.discoveryHash(key.secret);
      final discoveredPeer = DiscoveredPeer(
        peerId: 'remote_peer_1',
        address: '127.0.0.1',
        tcpPort: 12345,
        matchingHashes: [hash],
      );

      // Внутренний обработчик обнаружения пира
      engine.handlePeerDiscovered(discoveredPeer);
      expect(engine.activePeersFor(key), 1);

      engine.unregisterVault(key);
      expect(engine.activePeersFor(key), 0);
      engine.dispose();
    });
  });
}
