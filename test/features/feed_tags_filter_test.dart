import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transmitter/app/l10n.dart';
import 'package:transmitter/app/vault_session_factory.dart';
import 'package:transmitter/core/crypto/aes_gcm_cipher.dart';
import 'package:transmitter/core/files/external_opener.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/files/media_picker.dart';
import 'package:transmitter/core/share/outgoing_share.dart';
import 'package:transmitter/core/storage/cloud_provider_id.dart';
import 'package:transmitter/core/storage/in_memory_cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key.dart';
import 'package:transmitter/data/encrypted_cloud_post_repository.dart';
import 'package:transmitter/data/post_repository.dart';
import 'package:transmitter/features/feed/feed_controller.dart';
import 'package:transmitter/features/feed/feed_screen.dart';

import '../support/fake_file_transfer_service.dart';

class _FakeSessionFactory implements VaultSessionFactory {
  _FakeSessionFactory(this.repo);

  final PostRepository repo;

  @override
  Future<PostRepository> open(VaultKey key) async => repo;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('лента постов: фильтрация по чипам тегов и клику по тегу в посте', (
    tester,
  ) async {
    final cloud = InMemoryCloudStorage();
    final repo = EncryptedCloudPostRepository(
      storage: cloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 1)),
      deviceName: 'Device',
    );
    final files = FakeFileTransferService();

    // Создаём посты
    await repo.savePost(
      text: 'Пост 1 #работа #проект',
      attachment: null,
      folder: null,
    );
    await repo.savePost(
      text: 'Пост 2 #личное',
      attachment: null,
      folder: null,
    );

    final key = VaultKey(
      secret: List<int>.filled(32, 1),
      provider: CloudProviderId.dropbox,
      label: 'Доска',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<VaultSessionFactory>(
            create: (_) => _FakeSessionFactory(repo),
          ),
          Provider<FileTransferService>(create: (_) => files),
          Provider<MediaPicker>(create: (_) => const NoMediaPicker()),
          Provider<ExternalOpener>(create: (_) => const NoExternalOpener()),
          Provider<ShareSender>(create: (_) => const DisabledShareSender()),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: FeedScreen.vault(key),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Оба поста видны в начале
    expect(find.textContaining('Пост 1'), findsOneWidget);
    expect(find.textContaining('Пост 2'), findsOneWidget);

    // Панель чипов содержит 'Все', '#личное', '#проект', '#работа'
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('#личное'), findsNWidgets(2)); // один в чипе, один в посте
    expect(find.text('#работа'), findsNWidgets(2));

    // Нажимаем на чип '#работа'
    await tester.tap(find.widgetWithText(FilterChip, '#работа'));
    await tester.pumpAndSettle();

    // Виден только Пост 1
    expect(find.textContaining('Пост 1'), findsOneWidget);
    expect(find.textContaining('Пост 2'), findsNothing);

    // Нажимаем на чип '#личное'
    await tester.tap(find.widgetWithText(FilterChip, '#личное'));
    await tester.pumpAndSettle();

    // Виден только Пост 2
    expect(find.textContaining('Пост 1'), findsNothing);
    expect(find.textContaining('Пост 2'), findsOneWidget);

    // Нажимаем 'Все'
    await tester.tap(find.widgetWithText(FilterChip, 'Все'));
    await tester.pumpAndSettle();

    // Снова видны оба поста
    expect(find.textContaining('Пост 1'), findsOneWidget);
    expect(find.textContaining('Пост 2'), findsOneWidget);
  });
}
