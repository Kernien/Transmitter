import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'playable_source_stub.dart' show PlayableSource;

export 'playable_source_stub.dart' show PlayableSource;

/// Плееры играют только из файла: расшифровываем во временную папку
/// приложения и удаляем, когда плеер закрыт.
Future<PlayableSource> preparePlayable({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) async {
  final folder = Directory(
    '${(await getTemporaryDirectory()).path}/play/'
    '${Random.secure().nextInt(1 << 32)}',
  );
  await folder.create(recursive: true);
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot);
  final file = File('${folder.path}/media$extension');
  await file.writeAsBytes(bytes, flush: true);
  return _FileSource(folder, file);
}

class _FileSource implements PlayableSource {
  _FileSource(this._folder, this._file);

  final Directory _folder;
  final File _file;

  @override
  VideoPlayerController controller() => VideoPlayerController.file(_file);

  @override
  Future<void> dispose() async {
    try {
      await _folder.delete(recursive: true);
    } on FileSystemException {
      // Плеер ещё держит файл — уберётся вместе с временной папкой.
    }
  }
}
