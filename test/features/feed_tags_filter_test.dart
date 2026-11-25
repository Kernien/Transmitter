import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
import 'package:transmitter/features/feed/feed_screen.dart';
import 'package:transmitter/l10n/app_localizations.dart';

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
    await repo.sendText('Пост 1 #работа #проект');
    await repo.sendText('Пост 2 #личное');

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('вкладка файлов: бейджи тегов и фильтрация чипами', (tester) async {
    final cloud = InMemoryCloudStorage();
    final repo = EncryptedCloudPostRepository(
      storage: cloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 1)),
      deviceName: 'Device',
    );
    final files = FakeFileTransferService();

    final postFile = await repo.sendFile(
      fileName: 'document.pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
      caption: 'Документ #важно',
    );
    await repo.updatePostTags(postFile, ['отчёт']);

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedScreen.vault(key),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Переключаемся на вкладку «Файлы»
    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();

    // Виден файл document.pdf
    expect(find.text('document.pdf'), findsOneWidget);

    // На карточке видны бейджи #важно и #отчёт
    expect(find.text('#важно'), findsAtLeastNWidgets(1));
    expect(find.text('#отчёт'), findsAtLeastNWidgets(1));
  });

  testWidgets('лента: удаление тега через контекстное меню чипа', (tester) async {
    final cloud = InMemoryCloudStorage();
    final repo = EncryptedCloudPostRepository(
      storage: cloud,
      vaultId: 'v',
      cipher: AesGcmCipher(List<int>.filled(32, 1)),
      deviceName: 'Device',
    );
    final files = FakeFileTransferService();

    final post = await repo.sendText('Заметка без тегов в тексте');
    await repo.updatePostTags(post, ['вручную']);

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedScreen.vault(key),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('#вручную'), findsAtLeastNWidgets(1));

    // Вызываем контекстное меню по долгому тапу или вторичному клику
    await tester.longPress(find.widgetWithText(FilterChip, '#вручную'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить тег'), findsOneWidget);

    await tester.tap(find.text('Удалить тег'));
    await tester.pumpAndSettle();

    // Диалог подтверждения
    expect(find.text('Удалить тег #вручную?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить тег'));
    await tester.pumpAndSettle();

    // Тег удалён из ленты и из явных тегов
    expect(find.widgetWithText(FilterChip, '#вручную'), findsNothing);
  });
}
