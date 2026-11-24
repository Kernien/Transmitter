import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/widgets/post_tile.dart';
import 'package:transmitter/l10n/app_localizations.dart';

import '../support/fake_file_transfer_service.dart';

void main() {
  testWidgets('«Выделить текст» показывает текст и комментарий для выделения', (
    tester,
  ) async {
    final feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'A',
      ),
      files: FakeFileTransferService(),
      pollInterval: const Duration(hours: 1),
    );
    await tester.runAsync(() async {
      await feed.sendText('Купить молоко и хлеб');
      await feed.setNote(feed.posts.single, 'до вечера');
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: feed,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PostTile(post: feed.posts.single)),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выделить текст'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Купить молоко и хлеб')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('до вечера')),
      findsOneWidget,
    );

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    feed.dispose();
  });

  testWidgets(
    'показывает процент и кружок вместо значка скачивания при передаче файла',
    (tester) async {
      final cloud = _BlockingCloud();
      final files = FakeFileTransferService();
      final feed = FeedController(
        EncryptedCloudPostRepository(
          storage: cloud,
          vaultId: 'v',
          cipher: AesGcmCipher(List<int>.filled(32, 1)),
          deviceName: 'A',
        ),
        files: files,
        pollInterval: const Duration(hours: 1),
      );

      files.nextPick = PickedFile(
        name: 'archive.zip',
        bytes: Uint8List(1024 * 1024),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: feed,
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer<FeedController>(
                builder: (_, f, _) => f.posts.isEmpty
                    ? const SizedBox.shrink()
                    : PostTile(post: f.posts.first),
              ),
            ),
          ),
        ),
      );

      // Задерживаем загрузку в облако, чтобы проверить промежуточное состояние
      final gate = Completer<void>();
      cloud.uploadGate = gate;

      final future = feed.attachFile();
      await tester.pump();

      // Во время отправки отображается кружок прогресса, а не кнопка скачивания
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.text('archive.zip'), findsOneWidget);

      // Отпускаем загрузку
      gate.complete();
      await future;
      await tester.pumpAndSettle();

      // После отправки появляется кнопка скачивания
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      feed.dispose();
    },
  );

  testWidgets('в меню действий файла есть «Заменить файл» и «Переименовать»', (tester) async {
    final files = FakeFileTransferService();
    final feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'A',
      ),
      files: files,
      pollInterval: const Duration(hours: 1),
    );

    files.nextPick = PickedFile(
      name: 'file.txt',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    await tester.runAsync(() => feed.attachFile());

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: feed,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer<FeedController>(
              builder: (_, f, _) => PostTile(post: f.posts.first),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Заменить файл'), findsOneWidget);
    expect(find.text('Переименовать'), findsOneWidget);

    feed.dispose();
  });

  testWidgets('переименование файла обновляет имя на карточке поста', (tester) async {
    final files = FakeFileTransferService();
    final feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'A',
      ),
      files: files,
      pollInterval: const Duration(hours: 1),
    );

    files.nextPick = PickedFile(
      name: 'old_name.txt',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    await tester.runAsync(() => feed.attachFile());

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: feed,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer<FeedController>(
              builder: (_, f, _) => PostTile(post: f.posts.first),
            ),
          ),
        ),
      ),
    );

    expect(find.text('old_name.txt'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();

    // Вводим новое имя в диалоге
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'new_name.txt');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Переименовать'));
    await tester.pumpAndSettle();

    expect(find.text('new_name.txt'), findsOneWidget);
    expect(find.text('old_name.txt'), findsNothing);

    feed.dispose();
  });

  testWidgets('замена файла заменяет файл в посте', (tester) async {
    final files = FakeFileTransferService();
    final feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'A',
      ),
      files: files,
      pollInterval: const Duration(hours: 1),
    );

    files.nextPick = PickedFile(
      name: 'first.txt',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    await tester.runAsync(() => feed.attachFile());

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: feed,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer<FeedController>(
              builder: (_, f, _) => PostTile(post: f.posts.first),
            ),
          ),
        ),
      ),
    );

    expect(find.text('first.txt'), findsOneWidget);

    // Подготавливаем заменяющий файл
    files.nextPick = PickedFile(
      name: 'second.txt',
      bytes: Uint8List.fromList([4, 5, 6, 7]),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заменить файл'));
    await tester.pumpAndSettle();

    expect(find.text('second.txt'), findsOneWidget);
    expect(find.text('first.txt'), findsNothing);

    feed.dispose();
  });

  testWidgets('PostTile: отображает теги и вызывает onTagTap при клике', (
    tester,
  ) async {
    final feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'A',
      ),
      files: FakeFileTransferService(),
      pollInterval: const Duration(hours: 1),
    );
    await tester.runAsync(() async {
      await feed.sendText('Заметка #проект #важное');
    });

    String? tappedTag;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: feed,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PostTile(
              post: feed.posts.single,
              onTagTap: (tag) => tappedTag = tag,
            ),
          ),
        ),
      ),
    );

    expect(find.text('#проект'), findsOneWidget);
    expect(find.text('#важное'), findsOneWidget);

    await tester.tap(find.text('#важное'));
    await tester.pumpAndSettle();

    expect(tappedTag, 'важное');
    feed.dispose();
  });

  testWidgets('ПКМ на карточке поста открывает меню действий', (tester) async {
    final feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'A',
      ),
      files: FakeFileTransferService(),
      pollInterval: const Duration(hours: 1),
    );
    await tester.runAsync(() async {
      await feed.sendText('Текст поста');
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: feed,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PostTile(post: feed.posts.single)),
        ),
      ),
    );

    // ПКМ на посте
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Текст поста')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Выбрать'), findsOneWidget);
    expect(find.text('Копировать текст'), findsOneWidget);
    expect(find.text('Удалить для всех устройств'), findsOneWidget);

    feed.dispose();
  });
}

class _BlockingCloud extends InMemoryCloudStorage {
  Completer<void>? uploadGate;

  @override
  Future<void> upload(
    String path,
    Uint8List bytes, {
    ProgressCallback? onProgress,
  }) async {
    await super.upload(path, bytes, onProgress: onProgress);
    if (uploadGate != null) await uploadGate!.future;
  }
}
