import 'dart:typed_data';

import 'package:video_player/video_player.dart';

/// Расшифрованный файл, готовый для плеера. [dispose] убирает его следы.
abstract interface class PlayableSource {
  VideoPlayerController controller();

  Future<void> dispose();
}

Future<PlayableSource> preparePlayable({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) => throw UnsupportedError('Playback is not supported on this platform');
