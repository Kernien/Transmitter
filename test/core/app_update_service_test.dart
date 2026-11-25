import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transmitter/core/update/app_update_service.dart';

void main() {
  group('AppUpdateService.isNewer', () {
    test('корректно сравнивает версии', () {
      expect(AppUpdateService.isNewer('1.7.2', '1.7.1'), isTrue);
      expect(AppUpdateService.isNewer('1.8.0', '1.7.9'), isTrue);
      expect(AppUpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(AppUpdateService.isNewer('1.7.1', '1.7.1'), isFalse);
      expect(AppUpdateService.isNewer('1.7.0', '1.7.1'), isFalse);
      expect(AppUpdateService.isNewer('1.6.9', '1.7.0'), isFalse);
    });
  });

  group('checkLatestRelease', () {
    test('парсит последний релиз из ответа GitHub API', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('releases/latest')) {
          final body = jsonEncode({
            'tag_name': 'v1.7.2',
            'html_url': 'https://github.com/Kernien/Transmitter/releases/tag/v1.7.2',
            'body': 'Новые возможности и исправления',
            'assets': [
              {
                'name': 'Transmitter-1.7.2-windows-setup.exe',
                'browser_download_url': 'https://example.com/setup.exe',
              },
              {
                'name': 'Transmitter-1.7.2-linux-x86_64.AppImage.zsync',
                'browser_download_url': 'https://example.com/appimage.zsync',
              },
              {
                'name': 'Transmitter-1.7.2-linux-x86_64.AppImage',
                'browser_download_url': 'https://example.com/appimage',
              },
            ],
          });
          return http.Response(body, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService(
        client: mockClient,
        currentVersion: '1.7.1',
      );

      final release = await service.checkLatestRelease();
      expect(release, isNotNull);
      expect(release!.version, '1.7.2');
      expect(release.appImageUrl, 'https://example.com/appimage');
      expect(release.releaseUrl, 'https://github.com/Kernien/Transmitter/releases/tag/v1.7.2');
      expect(AppUpdateService.isNewer(release.version, service.currentVersion), isTrue);
    });
  });

  group('downloadAndApplyAppImage', () {
    test('скачивает файл и атомарно заменяет целевой AppImage', () async {
      final tempDir = await Directory.systemTemp.createTemp('appimage_test_');
      final targetAppImage = File('${tempDir.path}/Transmitter.AppImage');
      await targetAppImage.writeAsString('OLD_APPIMAGE_CONTENT');

      final newBytes = utf8.encode('NEW_APPIMAGE_UPDATED_CONTENT');

      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          newBytes,
          200,
          headers: {'content-length': newBytes.length.toString()},
        );
      });

      final service = AppUpdateService(
        client: mockClient,
        currentVersion: '1.7.1',
        appImageOverride: targetAppImage.path,
      );

      expect(service.isAppImage, isTrue);
      expect(service.appImagePath, targetAppImage.path);

      final progressValues = <double>[];
      await for (final progress in service.downloadAndApplyAppImage('https://example.com/new.AppImage')) {
        progressValues.add(progress);
      }

      expect(progressValues, isNotEmpty);
      expect(progressValues.last, 1.0);

      // Проверяем, что файл заменился новым содержимым
      final updatedContent = await targetAppImage.readAsString();
      expect(updatedContent, 'NEW_APPIMAGE_UPDATED_CONTENT');

      await tempDir.delete(recursive: true);
    });
  });
}
