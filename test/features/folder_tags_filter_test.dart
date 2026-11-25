import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/l10n.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/domain/post.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/folder_viewer_screen.dart';

import '../support/fake_file_transfer_service.dart';

void main() {
  Widget testApp({required Widget child, required FeedController feed}) =>
      MultiProvider(
        providers: [ChangeNotifierProvider<FeedController>.value(value: feed)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: child,
        ),
      );

  testWidgets(
    'FolderViewerScreen: отображение чипов тегов, бейджей и фильтрация',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final cloud = InMemoryCloudStorage();
      final files = FakeFileTransferService();
      final controller = FeedController(
        EncryptedCloudPostRepository(
          storage: cloud,
          vaultId: 'v',
          cipher: AesGcmCipher(List<int>.filled(32, 5)),
          deviceName: 'Phone',
        ),
        files: files,
        pollInterval: const Duration(hours: 1),
      );

      final post = Post(
        id: 'post_folder',
        kind: PostKind.folder,
        createdAt: DateTime.utc(2026, 11, 25),
        senderDevice: 'Phone',
        folder: const FolderAttachment(
          name: 'Архив',
          files: [
            FolderEntry(
              id: 'f1',
              relativePath: 'src/main.dart',
              size: 200,
              tags: ['flutter'],
            ),
            FolderEntry(
              id: 'f2',
              relativePath: 'readme.txt',
              size: 100,
              tags: ['дока'],
            ),
            FolderEntry(
              id: 'f3',
              relativePath: 'notes.txt',
              size: 50,
              tags: [],
            ),
          ],
          dirTags: {
            'src': ['код'],
          },
        ),
      );

      await tester.pumpWidget(
        testApp(
          feed: controller,
          child: FolderViewerScreen(feed: controller, post: post),
        ),
      );
      await tester.pumpAndSettle();

      // Видим полосу чипов фильтрации: «Все», «#flutter», «#дока», «#код»
      expect(find.widgetWithText(FilterChip, 'Все'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '#flutter'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '#дока'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '#код'), findsOneWidget);

      // В списке папки в корне видны подпапка src и файлы readme.txt, notes.txt
      expect(find.text('src'), findsOneWidget);
      expect(find.text('readme.txt'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);

      // На карточке подпапки src отображается плашка #код
      expect(find.text('#код'), findsAtLeastNWidgets(1));
      // На карточке файла readme.txt отображается плашка #дока
      expect(find.text('#дока'), findsAtLeastNWidgets(1));

      // Фильтруем по тегу #дока
      await tester.tap(find.widgetWithText(FilterChip, '#дока'));
      await tester.pumpAndSettle();

      // Виден только readme.txt, а notes.txt и src скрыты
      expect(find.text('readme.txt'), findsOneWidget);
      expect(find.text('notes.txt'), findsNothing);
      expect(find.text('src'), findsNothing);

      // Сбрасываем фильтр нажатием «Все»
      await tester.tap(find.widgetWithText(FilterChip, 'Все'));
      await tester.pumpAndSettle();

      expect(find.text('readme.txt'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('src'), findsOneWidget);

      // Фильтруем по тегу #код — отображается подпапка src
      await tester.tap(find.widgetWithText(FilterChip, '#код'));
      await tester.pumpAndSettle();

      expect(find.text('src'), findsOneWidget);
      expect(find.text('readme.txt'), findsNothing);
      expect(find.text('notes.txt'), findsNothing);
    },
  );
}
