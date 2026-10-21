import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

/// Расшифрованный файл, готовый для плеера. [dispose] убирает его следы.
abstract interface class PlayableSource {
  Media media();

  Future<void> dispose();
}

Future<PlayableSource> preparePlayable({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) => throw UnsupportedError('Playback is not supported on this platform');
