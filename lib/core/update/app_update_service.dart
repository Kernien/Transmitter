import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Информация о последнем релизе на GitHub.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.appImageUrl,
    required this.releaseUrl,
    required this.body,
  });

  final String version;
  final String? appImageUrl;
  final String releaseUrl;
  final String body;
}

/// Сервис проверки и применения обновлений для приложения.
class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    this.currentVersion = defaultCurrentVersion,
    this.appImageOverride,
  })  : _client = client ?? http.Client();

  static const String defaultCurrentVersion = '1.7.1';
  static const String _latestReleaseApiUrl =
      'https://api.github.com/repos/Kernien/Transmitter/releases/latest';

  final http.Client _client;
  final String currentVersion;
  final String? appImageOverride;

  /// Запущено ли приложение как AppImage в Linux.
  bool get isAppImage {
    if (appImageOverride != null) return true;
    if (kIsWeb) return false;
    return Platform.isLinux &&
        (Platform.environment['APPIMAGE']?.isNotEmpty ?? false);
  }

  /// Путь к исполняемому файлу AppImage на диске.
  String? get appImagePath {
    if (appImageOverride != null) return appImageOverride;
    if (!isAppImage) return null;
    return Platform.environment['APPIMAGE'];
  }

  /// Проверяет последний релиз на GitHub Releases.
  Future<ReleaseInfo?> checkLatestRelease() async {
    try {
      final response = await _client.get(
        Uri.parse(_latestReleaseApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Transmitter-App',
        },
      );
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName =
          (json['tag_name'] as String? ?? '').replaceFirst('v', '').trim();
      final htmlUrl = json['html_url'] as String? ??
          'https://github.com/Kernien/Transmitter/releases';
      final body = json['body'] as String? ?? '';

      String? appImageUrl;
      final assets = json['assets'] as List?;
      if (assets != null) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = asset['name'] as String? ?? '';
            if (name.contains('linux-x86_64.AppImage') &&
                !name.endsWith('.zsync')) {
              appImageUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }
      }

      return ReleaseInfo(
        version: tagName,
        appImageUrl: appImageUrl,
        releaseUrl: htmlUrl,
        body: body,
      );
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
      return null;
    }
  }

  /// Проверяет, новее ли [latest], чем [current].
  static bool isNewer(String latest, String current) {
    final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = lParts.length > cParts.length ? lParts.length : cParts.length;
    for (var i = 0; i < maxLen; i++) {
      final l = i < lParts.length ? lParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Скачивает новый AppImage с отслеживанием прогресса (0.0..1.0) и заменяет текущий файл.
  Stream<double> downloadAndApplyAppImage(String downloadUrl) async* {
    final path = appImagePath;
    if (path == null) throw StateError('Not running inside an AppImage');

    final request = http.Request('GET', Uri.parse(downloadUrl));
    request.headers['User-Agent'] = 'Transmitter-App';
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download update: HTTP ${response.statusCode}',
      );
    }

    final totalBytes = response.contentLength ?? 0;
    final tempPath = '$path.update.tmp';
    final tempFile = File(tempPath);
    final raf = tempFile.openSync(mode: FileMode.write);

    var receivedBytes = 0;
    try {
      await for (final chunk in response.stream) {
        raf.writeFromSync(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          yield receivedBytes / totalBytes;
        }
      }
    } finally {
      raf.closeSync();
    }

    // Делаем исполняемым (на Linux/macOS)
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', tempPath]);
    }

    // Атомарно заменяем старый AppImage файл новым
    if (Platform.isWindows && File(path).existsSync()) {
      File(path).deleteSync();
    }
    tempFile.renameSync(path);

    yield 1.0;
  }

  /// Запускает обновлённый AppImage и завершает текущий процесс.
  Future<void> restartAppImage() async {
    final path = appImagePath;
    if (path == null) return;
    await Process.start(path, [], mode: ProcessStartMode.detached);
    exit(0);
  }
}
