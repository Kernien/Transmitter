import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Файл для отправки в другое приложение.
class OutgoingFile {
  const OutgoingFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;
}

/// «Поделиться» из Transmitter в другие приложения.
abstract interface class ShareSender {
  /// Есть ли на платформе системное меню «Поделиться».
  bool get isAvailable;

  Future<void> share({String? text, List<OutgoingFile> files = const []});
}

/// Для платформ без системного меню «Поделиться».
class DisabledShareSender implements ShareSender {
  const DisabledShareSender();

  @override
  bool get isAvailable => false;

  @override
  Future<void> share({
    String? text,
    List<OutgoingFile> files = const [],
  }) async {}
}

class SharePlusSender implements ShareSender {
  const SharePlusSender({required this.isAvailable});

  @override
  final bool isAvailable;

  @override
  Future<void> share({
    String? text,
    List<OutgoingFile> files = const [],
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text == null || text.isEmpty ? null : text,
        files: [
          for (final f in files)
            XFile.fromData(f.bytes, name: f.name, mimeType: f.mimeType),
        ],
        fileNameOverrides: files.isEmpty
            ? null
            : [for (final f in files) f.name],
      ),
    );
  }
}
