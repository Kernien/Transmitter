import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import 'playable_source_stub.dart' show PlayableSource;

export 'playable_source_stub.dart' show PlayableSource;

/// В браузере плеер играет по ссылке на данные в памяти страницы.
Future<PlayableSource> preparePlayable({
  required String fileName,
  required Uint8List bytes,
  String? mimeType,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? ''),
  );
  return _BlobSource(web.URL.createObjectURL(blob));
}

class _BlobSource implements PlayableSource {
  _BlobSource(this._url);

  final String _url;

  @override
  VideoPlayerController controller() =>
      VideoPlayerController.networkUrl(Uri.parse(_url));

  @override
  Future<void> dispose() async => web.URL.revokeObjectURL(_url);
}
