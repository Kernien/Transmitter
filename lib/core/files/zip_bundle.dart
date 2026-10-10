import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// Файл для упаковки в архив.
class BundleEntry {
  const BundleEntry(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Собирает zip-архив из нескольких файлов.
///
/// Файлы кладутся без сжатия: фото, видео и документы обычно уже сжаты, а
/// упаковка «как есть» работает мгновенно. Одинаковые имена получают
/// суффикс « (2)», « (3)»… На устройствах сборка идёт в отдельном потоке.
Future<Uint8List> buildZip(List<BundleEntry> entries) =>
    kIsWeb ? Future.value(_buildZip(entries)) : compute(_buildZip, entries);

Uint8List _buildZip(List<BundleEntry> entries) {
  final archive = Archive();
  final used = <String>{};
  for (final entry in entries) {
    final file = ArchiveFile.bytes(_uniqueName(entry.name, used), entry.bytes)
      ..compression = CompressionType.none;
    archive.addFile(file);
  }
  return ZipEncoder().encodeBytes(archive);
}

String _uniqueName(String name, Set<String> used) {
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  var candidate = safe;
  final dot = safe.lastIndexOf('.');
  final (base, ext) = dot > 0 ? (safe.substring(0, dot), safe.substring(dot)) : (safe, '');
  for (var i = 2; !used.add(candidate.toLowerCase()); i++) {
    candidate = '$base ($i)$ext';
  }
  return candidate;
}
