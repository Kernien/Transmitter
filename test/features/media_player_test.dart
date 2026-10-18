import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/domain/post.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/media_player_screen.dart';
import 'package:transmitter/features/feed/widgets/post_tile.dart';
import 'package:transmitter/l10n/app_localizations.dart';

import '../support/fake_file_transfer_service.dart';
import 'open_with_test.dart' show FakeOpener;

void main() {
  test('видео и музыка распознаются', () {
    Attachment file(String name, [String? mime]) =>
        Attachment(id: 'a', fileName: name, size: 1, mimeType: mime);
    expect(file('отпуск.MP4').isVideo, isTrue);
    expect(file('x', 'video/quicktime').isVideo, isTrue);
    expect(file('песня.mp3').isAudio, isTrue);
    expect(file('голосовое.ogg').isAudio, isTrue);
    expect(file('x', 'audio/flac').isAudio, isTrue);
    expect(file('фото.jpg').isVideo, isFalse);
    expect(file('фото.jpg').isAudio, isFalse);
  });

  testWidgets(
    'нажатие на музыку открывает плеер; не играет — «Открыть в другом приложении»',
    (tester) async {
      final feed = FeedController(
        EncryptedCloudPostRepository(
          storage: InMemoryCloudStorage(),
          vaultId: 'v',
          cipher: AesGcmCipher(List<int>.filled(32, 1)),
          deviceName: 'A',
        ),
        files: FakeFileTransferService()
          ..nextPick = PickedFile(
            name: 'песня.mp3',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        opener: FakeOpener(),
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
      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);

      await tester.tap(find.text('песня.mp3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MediaPlayerScreen), findsOneWidget);

      // В тестах настоящего проигрывателя нет — срабатывает запасной путь.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.textContaining('не воспроизвести'), findsOneWidget);
      expect(find.text('Открыть в другом приложении'), findsOneWidget);
      feed.dispose();
    },
  );
}
