import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

import '../support/fake_file_transfer_service.dart';

void main() {
  testWidgets('нажатие на текстовый файл открывает его в приложении', (
    tester,
  ) async {
    final feed = FeedController(
      EncryptedCloudPostRepository(
        storage: InMemoryCloudStorage(),
        vaultId: 'v',
        cipher: AesGcmCipher(List<int>.filled(32, 1)),
        deviceName: 'A',
      ),
      files: FakeFileTransferService()
        ..nextPick = PickedFile(
          name: 'список.txt',
          bytes: Uint8List.fromList(utf8.encode('Молоко\nХлеб')),
        ),
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

    await tester.tap(find.text('список.txt'));
    await tester.pumpAndSettle();
    expect(find.byType(TextViewerScreen), findsOneWidget);

    await tester.runAsync(
      () => feed.previews.load(feed.posts.single.attachment!),
    );
    await tester.pumpAndSettle();
    expect(find.text('Молоко\nХлеб'), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);
    feed.dispose();
  });
}
