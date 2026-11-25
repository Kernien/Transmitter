import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transmitter/core/update/app_update_service.dart';
import 'package:transmitter/features/settings/about_dialog.dart';
import 'package:transmitter/l10n/app_localizations.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('AboutDialog: актуальная версия установлена', (tester) async {
    final mockClient = MockClient((request) async {
      final body = jsonEncode({
        'tag_name': 'v1.7.1',
        'html_url': 'https://github.com/Kernien/Transmitter/releases',
        'body': 'Актуальный релиз',
        'assets': [],
      });
      return http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = AppUpdateService(
      client: mockClient,
      currentVersion: '1.7.1',
    );

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAboutAppDialog(context, updateService: service),
            child: const Text('Открыть'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Transmitter'), findsOneWidget);
    expect(find.text('Версия 1.7.1'), findsOneWidget);
    expect(find.text('У вас установлена актуальная версия'), findsOneWidget);
  });

  testWidgets('AboutDialog: в AppImage доступна новая версия и кнопка «Обновить приложение»', (
    tester,
  ) async {
    late Directory tempDir;
    late File dummyAppImage;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('appimage_ui_test_');
      dummyAppImage = File('${tempDir.path}/Transmitter.AppImage');
      await dummyAppImage.writeAsString('OLD_CONTENT');
    });

    final newBytes = utf8.encode('NEW_CONTENT');

    final mockClient = MockClient((request) async {
      if (request.url.toString().contains('releases/latest')) {
        final body = jsonEncode({
          'tag_name': 'v1.8.0',
          'html_url': 'https://github.com/Kernien/Transmitter/releases/tag/v1.8.0',
          'body': 'Новый релиз',
          'assets': [
            {
              'name': 'Transmitter-1.8.0-linux-x86_64.AppImage',
              'browser_download_url': 'https://example.com/download/AppImage',
            },
          ],
        });
        return http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      } else if (request.url.toString().contains('download/AppImage')) {
        return http.Response.bytes(
          newBytes,
          200,
          headers: {'content-length': newBytes.length.toString()},
        );
      }
      return http.Response('Not Found', 404);
    });

    final service = AppUpdateService(
      client: mockClient,
      currentVersion: '1.7.1',
      appImageOverride: dummyAppImage.path,
    );

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAboutAppDialog(context, updateService: service),
            child: const Text('Открыть'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // Обнаружена новая версия
    expect(find.text('Доступна новая версия: 1.8.0'), findsOneWidget);
    // Видна кнопка обновления AppImage
    final updateButton = find.widgetWithText(FilledButton, 'Обновить приложение');
    expect(updateButton, findsOneWidget);

    // Нажимаем обновить
    await tester.tap(updateButton);
    await tester.runAsync(() async {
      // Ждём, пока файл на диске завершит обновление через OS I/O
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        try {
          final content = await dummyAppImage.readAsString();
          if (content == 'NEW_CONTENT') break;
        } catch (_) {}
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Появилось сообщение об успешном обновлении и кнопка перезапуска
    expect(find.text('Обновление загружено! Нажмите для перезапуска.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Перезапустить'), findsOneWidget);

    // Проверяем, что файл действительно обновился
    late String updatedContent;
    await tester.runAsync(() async {
      updatedContent = await dummyAppImage.readAsString();
      await tempDir.delete(recursive: true);
    });
    expect(updatedContent, 'NEW_CONTENT');
  });
}
