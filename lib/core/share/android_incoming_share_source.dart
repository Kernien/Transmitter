import 'dart:async';

import 'package:flutter/services.dart';

import 'incoming_share.dart';

/// Приём «Поделиться» на Android. Нативная часть — ShareReceiver.kt.
class AndroidIncomingShareSource implements IncomingShareSource {
  AndroidIncomingShareSource({required this.maxFileSize});

  static const MethodChannel _channel = MethodChannel('app.transmitter/share');

  final int maxFileSize;

  // Не broadcast: поделиться могли до того, как UI подписался, — событие
  // подождёт в буфере.
  final StreamController<SharedContent> _shares = StreamController();
  bool _started = false;

  @override
  Stream<SharedContent> get shares {
    _start();
    return _shares.stream;
  }

  void _start() {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onShare') return;
      final payload = Map<String, Object?>.from(call.arguments as Map);
      final error = payload['error'] as String?;
      if (error != null) {
        _shares.addError(Exception(error));
      } else {
        final content = parse(payload);
        if (!content.isEmpty) _shares.add(content);
      }
    });
    _channel.invokeMethod('ready', {'maxSize': maxFileSize});
  }

  @override
  Future<void> returnToSourceApp() => _channel.invokeMethod('moveToBack');

  /// Разбор данных из нативной части (вынесен для тестов).
  static SharedContent parse(Map<String, Object?> payload) => SharedContent(
    text: payload['text'] as String?,
    subject: payload['subject'] as String?,
    files: [
      for (final raw in (payload['files'] as List? ?? const []))
        _parseFile(Map<String, Object?>.from(raw as Map)),
    ],
  );

  static SharedFile _parseFile(Map<String, Object?> raw) => SharedFile(
    name: raw['name'] as String? ?? 'file',
    size: (raw['size'] as num?)?.toInt() ?? 0,
    bytes: raw['bytes'] as Uint8List?,
    mimeType: raw['mimeType'] as String?,
  );
}
