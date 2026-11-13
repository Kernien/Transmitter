import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/l10n.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/domain/post.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/folder_viewer_screen.dart';
import 'package:transmitter/features/feed/widgets/post_tile.dart';

import '../support/fake_file_transfer_service.dart';

void main() {
  late InMemoryCloudStorage cloud;
  late FakeFileTransferService files;

  FeedController controllerFor(String device) => FeedController(
    EncryptedCloudPostRepository(
      storage: cloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 5)),
      deviceName: device,
    ),
    files: files,
    pollInterval: const Duration(hours: 1),
  );

  Widget testApp({required Widget child, required FeedController feed}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FeedController>.value(value: feed),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(body: child),
        ),
      );

  setUp(() {
    cloud = InMemoryCloudStorage();
    files = FakeFileTransferService();
  });

  test('отправка папки через FeedController и последующее сохранение', () async {
    final sender = controllerFor('Phone');
    final receiver = controllerFor('PC');

    files.nextPickedFolder = PickedFolder(
      name: 'archive_project',
      files: [
        PickedFile(
          name: 'README.md',
          bytes: Uint8List.fromList(utf8.encode('# Readme')),
          relativePath: 'README.md',
        ),
        PickedFile(
          name: 'empty.txt',
          bytes: Uint8List(0),
          relativePath: 'empty.txt',
        ),
        PickedFile(
          name: 'code.dart',
          bytes: Uint8List.fromList(utf8.encode('void main() {}')),
          relativePath: 'src/code.dart',
        ),
      ],
    );

    final attached = await sender.attachFolder(caption: 'исходный код');
    expect(attached, isTrue);
    expect(sender.posts, hasLength(1));
    expect(sender.posts.single.kind, PostKind.folder);
    expect(sender.posts.single.folder?.name, 'archive_project');
    expect(sender.posts.single.folder?.fileCount, 3);

    await receiver.refresh();
    expect(receiver.posts, hasLength(1));
    final post = receiver.posts.single;
    expect(post.folder?.name, 'archive_project');

    // Сохранение всей папки
    final saved = await receiver.saveFolder(post);
    expect(saved, isTrue);
    expect(files.savedFolders, hasLength(1));
    expect(files.savedFolders.single.$1, 'archive_project');
    expect(files.savedFolders.single.$2, hasLength(3));
    expect(files.saved, hasLength(3));

    // Сохранение отдельного файла
    final savedEntry = await receiver.saveFolderEntry(post.folder!.files.first);
    expect(savedEntry, isTrue);
    expect(files.saved.last.$1, 'README.md');

    sender.dispose();
    receiver.dispose();
  });

  testWidgets('отображение структуры папок и навигация в FolderViewerScreen', (tester) async {
    final feed = controllerFor('PC');
    final post = Post(
      id: 'p1',
      kind: PostKind.folder,
      createdAt: DateTime.utc(2026, 3, 1),
      senderDevice: 'MacBook',
      text: 'архив документов',
      folder: FolderAttachment(
        name: 'documents',
        files: [
          FolderEntry(
            id: 'f1',
            relativePath: 'report.txt',
            size: 1024,
          ),
          FolderEntry(
            id: 'f2',
            relativePath: 'sub/data.csv',
            size: 2048,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      testApp(child: PostTile(post: post), feed: feed),
    );
    await tester.pumpAndSettle();

    expect(find.text('documents'), findsOneWidget);
    expect(find.text('архив документов'), findsOneWidget);

    // Тап на карточку папки открывает FolderViewerScreen
    await tester.tap(find.text('documents'));
    await tester.pumpAndSettle();

    expect(find.byType(FolderViewerScreen), findsOneWidget);
    // На верхнем уровне виден report.txt и подпапка sub
    expect(find.text('report.txt'), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);

    // Тап по подпапке sub углубляется внутрь
    await tester.tap(find.text('sub'));
    await tester.pumpAndSettle();

    // Внутри sub виден data.csv, а report.txt скрыт
    expect(find.text('data.csv'), findsOneWidget);
    expect(find.text('report.txt'), findsNothing);

    // Возврат назад стрелкой
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Снова на корневом уровне
    expect(find.text('report.txt'), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);

    feed.dispose();
  });

  test('отмена отправки папки через cancelTransfer', () async {
    final sender = controllerFor('Phone');

    final folder = PickedFolder(
      name: 'large_folder',
      files: [
        PickedFile(
          name: 'large.bin',
          bytes: Uint8List(1024 * 1024),
          relativePath: 'large.bin',
        ),
      ],
    );

    // Начинаем отправку напрямую
    final sendFuture = sender.sendFolder(folder);

    // pendingPost добавляется сразу в sendFolder
    final pendingPost =
        sender.posts.firstWhere((p) => p.id.startsWith('pending_'));
    sender.cancelTransfer(pendingPost.id);

    final result = await sendFuture;
    expect(result, isFalse);
    expect(sender.posts, isEmpty);
    expect(sender.error, isNull);

    sender.dispose();
  });

  test('sendFolder загружает файлы папки параллельно до 6 потоков и сохраняет порядок', () async {
    final delayedCloud = _TrackingCloudStorage();
    final repo = EncryptedCloudPostRepository(
      storage: delayedCloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 5)),
      deviceName: 'PC',
    );

    final pickedFiles = [
      for (var i = 0; i < 15; i++)
        PickedFile(
          name: 'file_$i.txt',
          bytes: Uint8List.fromList(utf8.encode('content $i')),
          relativePath: 'sub/file_$i.txt',
        ),
    ];

    final post = await repo.sendFolder(
      folderName: 'parallel_folder',
      files: pickedFiles,
    );

    expect(delayedCloud.maxConcurrentUploads, greaterThan(1));
    expect(delayedCloud.maxConcurrentUploads, lessThanOrEqualTo(6));
    expect(post.folder!.files, hasLength(15));
    for (var i = 0; i < 15; i++) {
      expect(post.folder!.files[i].relativePath, 'sub/file_$i.txt');
    }
  });

  test('refresh во время загрузки папки с тем же именем не удаляет pending-карточку из ленты', () async {
    final delayedCloud = _TrackingCloudStorage();
    final repo = EncryptedCloudPostRepository(
      storage: delayedCloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 5)),
      deviceName: 'PC',
    );
    final sender = FeedController(
      repo,
      files: files,
      pollInterval: const Duration(hours: 1),
    );

    final folder = PickedFolder(
      name: 'Vault',
      files: [
        PickedFile(
          name: 'doc.md',
          bytes: Uint8List.fromList(utf8.encode('# Doc')),
          relativePath: 'doc.md',
        ),
      ],
    );

    // Первая папка 'Vault' уже есть на доске.
    await sender.sendFolder(folder);
    expect(sender.posts, hasLength(1));
    expect(sender.posts.single.folder?.name, 'Vault');

    // Начинаем отправку второй папки с тем же именем 'Vault'.
    final secondSend = sender.sendFolder(folder);
    expect(
      sender.posts.where((p) => p.id.startsWith('pending_')),
      hasLength(1),
    );

    // Во время отправки срабатывает фоновый refresh().
    await sender.refresh();

    // Pending-пост должен остаться в ленте до завершения загрузки!
    expect(
      sender.posts.where((p) => p.id.startsWith('pending_')),
      hasLength(1),
    );

    await secondSend;
    expect(
      sender.posts.where((p) => p.id.startsWith('pending_')),
      isEmpty,
    );
    expect(sender.posts, hasLength(2));

    sender.dispose();
  });

  test('управление файлами в загруженной папке: переименование, перемещение, замена, добавление и удаление', () async {
    final sender = controllerFor('PC');
    final receiver = controllerFor('Phone');

    final initialFolder = PickedFolder(
      name: 'NotesVault',
      files: [
        PickedFile(
          name: 'draft.md',
          bytes: Uint8List.fromList(utf8.encode('Черновик 1')),
          relativePath: 'drafts/draft.md',
        ),
        PickedFile(
          name: 'trash.tmp',
          bytes: Uint8List.fromList(utf8.encode('мусор')),
          relativePath: '.debris/trash.tmp',
        ),
      ],
    );

    await sender.sendFolder(initialFolder);
    var post = sender.posts.single;
    expect(post.folder!.files, hasLength(2));

    // 1. Удаляем подпапку .debris и переименовываем/перемещаем draft.md -> ready/final.md
    final draftEntry = post.folder!.files.firstWhere(
      (f) => f.relativePath == 'drafts/draft.md',
    );
    final trashEntry = post.folder!.files.firstWhere(
      (f) => f.relativePath == '.debris/trash.tmp',
    );

    post = (await sender.updateFolderStructure(
      post,
      FolderAttachment(
        name: 'NotesVault',
        files: [
          FolderEntry(
            id: draftEntry.id,
            relativePath: 'ready/final.md',
            size: draftEntry.size,
            mimeType: draftEntry.mimeType,
          ),
        ],
      ),
      removedEntryIds: [trashEntry.id],
    ))!;

    expect(post.folder!.files, hasLength(1));
    expect(post.folder!.files.single.relativePath, 'ready/final.md');
    // Файл мусора реально удалён из облака
    expect(
      cloud.files.keys.any((k) => k.contains(trashEntry.id)),
      isFalse,
    );

    // 2. Редактируем содержимое файла внутри папки (replaceFolderEntry)
    final updatedContent = Uint8List.fromList(utf8.encode('Финальный текст'));
    post = (await sender.replaceFolderEntry(
      post,
      draftEntry.id,
      updatedContent,
      newRelativePath: 'ready/final.md',
    ))!;
    expect(post.folder!.files, hasLength(1));
    final replacedEntry = post.folder!.files.single;
    expect(replacedEntry.id, isNot(equals(draftEntry.id)));
    expect(
      utf8.decode(await sender.downloadAttachment(replacedEntry.toAttachment())),
      'Финальный текст',
    );

    // 3. Добавляем новый файл в подпапку ready
    files.nextPick = PickedFile(
      name: 'extra.txt',
      bytes: Uint8List.fromList(utf8.encode('Дополнение')),
    );
    post = (await sender.pickAndAddFilesToFolder(
      post,
      targetSubdir: 'ready',
    ))!;
    expect(post.folder!.files, hasLength(2));
    expect(
      post.folder!.files.map((f) => f.relativePath),
      containsAll(['ready/final.md', 'ready/extra.txt']),
    );

    // 4. Второе устройство при refresh() видит все изменения структуры и содержимого
    await receiver.refresh();
    expect(receiver.posts, hasLength(1));
    final remoteFolder = receiver.posts.single.folder!;
    expect(remoteFolder.files, hasLength(2));
    final remoteFinal = remoteFolder.files.firstWhere(
      (f) => f.relativePath == 'ready/final.md',
    );
    expect(
      utf8.decode(await receiver.downloadAttachment(remoteFinal.toAttachment())),
      'Финальный текст',
    );

    sender.dispose();
    receiver.dispose();
  });
}

class _TrackingCloudStorage extends InMemoryCloudStorage {
  int _activeUploads = 0;
  int maxConcurrentUploads = 0;

  @override
  Future<void> upload(
    String path,
    Uint8List bytes, {
    void Function(int count, int total)? onProgress,
  }) async {
    if (path.contains('/files/')) {
      _activeUploads++;
      if (_activeUploads > maxConcurrentUploads) {
        maxConcurrentUploads = _activeUploads;
      }
      try {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await super.upload(path, bytes, onProgress: onProgress);
      } finally {
        _activeUploads--;
      }
    } else {
      await super.upload(path, bytes, onProgress: onProgress);
    }
  }
}
