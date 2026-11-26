import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Платформа для обновления приложения.
enum UpdatePlatform {
  appImage,
  windows,
  android,
  other,
}

/// Информация о последнем релизе на GitHub.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.releaseUrl,
    required this.body,
    this.appImageUrl,
    this.windowsSetupUrl,
    this.androidArm64Url,
    this.androidArmv7Url,
    this.androidUniversalUrl,
  });

  final String version;
  final String releaseUrl;
  final String body;
  final String? appImageUrl;
  final String? windowsSetupUrl;
  final String? androidArm64Url;
  final String? androidArmv7Url;
  final String? androidUniversalUrl;
}

/// Сервис проверки и применения обновлений для приложения.
class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    this.currentVersion = defaultCurrentVersion,
    this.appImageOverride,
    this.platformOverride,
    this.isArm32Override,
    this.apkFileProvider,
    this.windowsInstallerFileProvider,
  }) : _client = client ?? http.Client();

  static const String defaultCurrentVersion = '1.7.1';
  static const String _latestReleaseApiUrl =
      'https://api.github.com/repos/Kernien/Transmitter/releases/latest';

  static const MethodChannel _androidChannel =
      MethodChannel('app.transmitter/open');

  final http.Client _client;
  final String currentVersion;
  final String? appImageOverride;
  final UpdatePlatform? platformOverride;
  final bool? isArm32Override;
  final Future<File> Function()? apkFileProvider;
  final File Function(String? version)? windowsInstallerFileProvider;

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

  /// Текущая целевая платформа для обновлений.
  UpdatePlatform get platform {
    if (platformOverride != null) return platformOverride!;
    if (isAppImage) return UpdatePlatform.appImage;
    if (!kIsWeb && Platform.isWindows) return UpdatePlatform.windows;
    if (!kIsWeb && Platform.isAndroid) return UpdatePlatform.android;
    return UpdatePlatform.other;
  }

  /// Поддерживает ли текущая платформа автообновление в один клик.
  bool get canAutoUpdate => platform != UpdatePlatform.other;

  /// Проверяет, является ли архитектура Android 32-битным ARM.
  bool get isAndroidArm32 {
    if (isArm32Override != null) return isArm32Override!;
    if (kIsWeb) return false;
    final v = Platform.version.toLowerCase();
    return v.contains('android_arm') && !v.contains('arm64');
  }

  /// Возвращает ссылку на скачивание для текущей платформы из релиза.
  String? getDownloadUrlForCurrentPlatform(ReleaseInfo release) {
    switch (platform) {
      case UpdatePlatform.appImage:
        return release.appImageUrl;
      case UpdatePlatform.windows:
        return release.windowsSetupUrl;
      case UpdatePlatform.android:
        if (isAndroidArm32) {
          return release.androidArmv7Url ??
              release.androidUniversalUrl ??
              release.androidArm64Url;
        }
        return release.androidArm64Url ??
            release.androidUniversalUrl ??
            release.androidArmv7Url;
      case UpdatePlatform.other:
        return null;
    }
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
      String? windowsSetupUrl;
      String? androidArm64Url;
      String? androidArmv7Url;
      String? androidUniversalUrl;

      final assets = json['assets'] as List?;
      if (assets != null) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            final downloadUrl = asset['browser_download_url'] as String?;
            if (downloadUrl == null) continue;

            if (name.contains('linux-x86_64.appimage') &&
                !name.endsWith('.zsync')) {
              appImageUrl = downloadUrl;
            } else if (name.contains('-windows-setup.exe') ||
                name.endsWith('setup.exe')) {
              windowsSetupUrl = downloadUrl;
            } else if (name.endsWith('.apk')) {
              if (name.contains('arm64') || name.contains('arm64-v8a')) {
                androidArm64Url = downloadUrl;
              } else if (name.contains('armv7') ||
                  name.contains('armeabi-v7a')) {
                androidArmv7Url = downloadUrl;
              } else {
                androidUniversalUrl = downloadUrl;
              }
            }
          }
        }
      }

      return ReleaseInfo(
        version: tagName,
        releaseUrl: htmlUrl,
        body: body,
        appImageUrl: appImageUrl,
        windowsSetupUrl: windowsSetupUrl,
        androidArm64Url: androidArm64Url,
        androidArmv7Url: androidArmv7Url,
        androidUniversalUrl: androidUniversalUrl,
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

  /// Скачивает файл по [downloadUrl] в [destinationFile] с отслеживанием прогресса (0.0..1.0).
  Stream<double> downloadFile(
    String downloadUrl,
    File destinationFile,
  ) async* {
    if (!destinationFile.parent.existsSync()) {
      destinationFile.parent.createSync(recursive: true);
    }

    final request = http.Request('GET', Uri.parse(downloadUrl));
    request.headers['User-Agent'] = 'Transmitter-App';
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download update: HTTP ${response.statusCode}',
      );
    }

    final totalBytes = response.contentLength ?? 0;
    final raf = destinationFile.openSync(mode: FileMode.write);

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

    yield 1.0;
  }

  /// Скачивает новый AppImage с отслеживанием прогресса (0.0..1.0) и заменяет текущий файл.
  Stream<double> downloadAndApplyAppImage(String downloadUrl) async* {
    final path = appImagePath;
    if (path == null) throw StateError('Not running inside an AppImage');

    final tempPath = '$path.update.tmp';
    final tempFile = File(tempPath);
    yield* downloadFile(downloadUrl, tempFile);

    // Делаем исполняемым (на Linux/macOS)
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', tempPath]);
    }

    // Атомарно заменяем старый AppImage файл новым
    if (Platform.isWindows && File(path).existsSync()) {
      File(path).deleteSync();
    }
    tempFile.renameSync(path);
  }

  /// Запускает обновлённый AppImage и завершает текущий процесс.
  Future<void> restartAppImage() async {
    final path = appImagePath;
    if (path == null) return;
    await Process.start(path, [], mode: ProcessStartMode.detached);
    exit(0);
  }

  /// Возвращает путь к целевому файлу установщика Windows во временном каталоге.
  File getWindowsInstallerFile([String? version]) {
    if (windowsInstallerFileProvider != null) {
      return windowsInstallerFileProvider!(version);
    }
    final v = version ?? 'update';
    final tempDir = Directory.systemTemp;
    return File('${tempDir.path}${Platform.pathSeparator}Transmitter-$v-windows-setup.exe');
  }

  /// Скачивает установщик Windows во временную папку.
  Stream<double> downloadWindowsInstaller(
    String downloadUrl, {
    File? targetFile,
    String? version,
  }) async* {
    final file = targetFile ?? getWindowsInstallerFile(version);
    yield* downloadFile(downloadUrl, file);
  }

  /// Запускает установщик Windows с закрытием текущего приложения.
  Future<void> runWindowsInstaller({File? installerFile, String? version}) async {
    final file = installerFile ?? getWindowsInstallerFile(version);
    if (!file.existsSync()) {
      throw StateError('Installer not found at ${file.path}');
    }
    await Process.start(
      file.path,
      ['/CLOSEAPPLICATIONS'],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  /// Возвращает путь к целевому APK-файлу во временной папке open/.
  Future<File> getAndroidApkFile() async {
    if (apkFileProvider != null) {
      return apkFileProvider!();
    }
    final tempDir = await getTemporaryDirectory();
    final openDir = Directory('${tempDir.path}/open');
    if (!openDir.existsSync()) {
      openDir.createSync(recursive: true);
    }
    return File('${openDir.path}/update.apk');
  }

  /// Скачивает APK-файл для Android во временную папку open/.
  Stream<double> downloadAndroidApk(
    String downloadUrl, {
    File? targetFile,
  }) async* {
    final file = targetFile ?? await getAndroidApkFile();
    yield* downloadFile(downloadUrl, file);
  }

  /// Запускает установку APK через системный установщик Android.
  Future<void> installAndroidApk({File? apkFile}) async {
    final file = apkFile ?? await getAndroidApkFile();
    if (!file.existsSync()) {
      throw StateError('APK not found at ${file.path}');
    }
    await _androidChannel.invokeMethod('installApk', {'path': file.path});
  }
}
