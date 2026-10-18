import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../external_opener.dart';

ExternalOpener createPlatformExternalOpener() => const NativeExternalOpener();

/// Файл расшифровывается во временную папку приложения (`…/open/`) и
/// открывается: на Android — выбором приложения (FileOpener.kt), на
/// компьютере — программой по умолчанию. Копии удаляются при следующем
/// запуске ([cleanUp]): открытая программа может читать файл ещё долго.
class NativeExternalOpener implements ExternalOpener {
  const NativeExternalOpener();

  static const MethodChannel _android = MethodChannel('app.transmitter/open');

  @override
  bool get isAvailable => true;

  static Future<Directory> _root() async =>
      Directory('${(await getTemporaryDirectory()).path}/open');

  @override
  Future<void> open({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    // Своя папка на каждое открытие: имя файла остаётся как было.
    final folder = Directory(
      '${(await _root()).path}/${Random.secure().nextInt(1 << 32)}',
    );
    await folder.create(recursive: true);
    final file = File('${folder.path}/${_safeName(fileName)}');
    await file.writeAsBytes(bytes, flush: true);

    if (Platform.isAndroid) {
      try {
        await _android.invokeMethod('open', {
          'path': file.path,
          'mimeType': mimeType,
        });
      } on PlatformException catch (e) {
        if (e.code == 'no_app') throw const NoAppToOpenException();
        rethrow;
      }
      return;
    }
    if (!await launchUrl(Uri.file(file.path))) {
      throw const NoAppToOpenException();
    }
  }

  /// Заодно — копии для встроенного плеера (`…/play/`), если приложение
  /// закрылось, не успев их убрать.
  @override
  Future<void> cleanUp() async {
    final temp = (await getTemporaryDirectory()).path;
    for (final dir in [await _root(), Directory('$temp/play')]) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } on Object {
        // Файл ещё открыт в другой программе — удалим в следующий раз.
      }
    }
  }

  /// Имя без символов, недопустимых в файловых системах.
  static String _safeName(String name) {
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    return safe.isEmpty ? 'file' : safe;
  }
}
