import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
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
}
