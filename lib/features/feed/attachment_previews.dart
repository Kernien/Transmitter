import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../domain/post.dart';

/// Фото не больше этого размера загружаются в ленте сами; для больших —
/// кнопка «Показать фото».
const int attachmentPreviewAutoLimit = 10 * 1024 * 1024;

/// Содержимое вложений для показа в ленте (превью фото, просмотр).
///
/// Недавно показанные файлы держатся в памяти (не больше [maxBytes]), один
/// и тот же файл не качается дважды, даже если его просят одновременно
/// превью и полноэкранный просмотр. Кеш на диске — уровнем ниже, в
/// репозитории.
class AttachmentPreviews {
  AttachmentPreviews(this._load, {this.maxBytes = 64 * 1024 * 1024});

  final Future<Uint8List> Function(Attachment attachment) _load;
  final int maxBytes;

  final LinkedHashMap<String, Uint8List> _bytes = LinkedHashMap();
  final Map<String, Future<Uint8List>> _pending = {};
  int _total = 0;

  /// Уже загруженное содержимое без обращения к облаку; `null` — нет в памяти.
  Uint8List? peek(Attachment attachment) {
    final bytes = _bytes.remove(attachment.id);
    if (bytes != null) _bytes[attachment.id] = bytes; // свежее — в конец
    return bytes;
  }

  Future<Uint8List> load(Attachment attachment) {
    final ready = peek(attachment);
    if (ready != null) return SynchronousFuture(ready);
    return _pending[attachment.id] ??= _fetch(attachment);
  }

  Future<Uint8List> _fetch(Attachment attachment) async {
    try {
      final bytes = await _load(attachment);
      _remember(attachment.id, bytes);
      return bytes;
    } finally {
      _pending.remove(attachment.id);
    }
  }

  void _remember(String id, Uint8List bytes) {
    if (bytes.length > maxBytes) return;
    _bytes[id] = bytes;
    _total += bytes.length;
    while (_total > maxBytes && _bytes.isNotEmpty) {
      final oldest = _bytes.keys.first;
      _total -= _bytes.remove(oldest)!.length;
    }
  }
}
