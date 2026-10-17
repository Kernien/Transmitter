import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/text_viewer_screen.dart';
import 'package:transmitter/features/feed/widgets/post_tile.dart';
import 'package:transmitter/l10n/app_localizations.dart';

import '../core/docx_text_test.dart' show sampleDocx;
import '../support/fake_file_transfer_service.dart';

/// Отправляет файл в ленту, показывает его карточку и открывает нажатием.
Future<FeedController> openFile(
  WidgetTester tester,
  String name,
  List<int> bytes,
) async {
  final feed = FeedController(
    EncryptedCloudPostRepository(
      storage: InMemoryCloudStorage(),
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 1)),
      deviceName: 'A',
    ),
    files: FakeFileTransferService()
      ..nextPick = PickedFile(name: name, bytes: Uint8List.fromList(bytes)),
    pollInterval: const Duration(hours: 1),
  );
  await tester.runAsync(() => feed.attachFile());
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
  expect(find.byIcon(Icons.description_outlined), findsOneWidget);
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  expect(find.byType(TextViewerScreen), findsOneWidget);
  await tester.runAsync(
    () => feed.previews.load(feed.posts.single.attachment!),
  );
  await tester.pumpAndSettle();
  return feed;
}

void main() {
  testWidgets('текстовый файл открывается в приложении', (tester) async {
    final feed = await openFile(
      tester,
      'список.txt',
      utf8.encode('Молоко\nХлеб'),
    );
    expect(find.text('Молоко\nХлеб'), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);

    // Шрифт и «Копировать всё» — в меню ⋮.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Моноширинный шрифт'), findsOneWidget);
    expect(find.text('Копировать всё'), findsOneWidget);
    feed.dispose();
  });

  testWidgets('Markdown показывается с оформлением', (tester) async {
    final feed = await openFile(
      tester,
      'README.md',
      utf8.encode('# Заголовок\n\nТекст с **жирным**.'),
    );
    expect(find.byType(Markdown), findsOneWidget);
    expect(find.textContaining('# Заголовок'), findsNothing);
    expect(find.textContaining('Заголовок'), findsWidgets);

    // Исходный текст — по пункту меню.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать исходный текст'));
    await tester.pumpAndSettle();
    expect(find.textContaining('# Заголовок'), findsOneWidget);
    feed.dispose();
  });

  testWidgets('текст из .docx', (tester) async {
    final feed = await openFile(tester, 'отчёт.docx', sampleDocx());
    expect(find.textContaining('Отчёт за неделю'), findsOneWidget);
    expect(find.textContaining('всё готово'), findsOneWidget);
    feed.dispose();
  });
}
