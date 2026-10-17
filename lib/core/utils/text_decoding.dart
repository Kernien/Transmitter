import 'dart:convert';

/// Текст файла для показа в приложении.
class TextPreview {
  const TextPreview(this.text, {required this.truncated});

  final String text;

  /// Показано только начало файла.
  final bool truncated;
}

/// Расшифровка текстового файла: UTF-8 (с BOM и без), UTF-16 с BOM, а если
/// это не UTF-8 — Windows-1251 (так сохранены многие русские `.txt` из
/// Windows). Показывается не больше [maxBytes] байт начала файла.
TextPreview decodeTextPreview(List<int> bytes, {int maxBytes = 512 * 1024}) {
  // UTF-16 по метке порядка байтов.
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    final littleEndian = bytes[0] == 0xFF;
    final end = (bytes.length < maxBytes ? bytes.length : maxBytes) & ~1;
    final units = <int>[
      for (var i = 2; i + 1 < end; i += 2)
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
    ];
    return TextPreview(
      String.fromCharCodes(units),
      truncated: end < bytes.length,
    );
  }

  final start =
      bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? 3
      : 0;
  final truncated = bytes.length - start > maxBytes;
  final end = truncated ? start + maxBytes : bytes.length;

  // Проверяем только показываемую часть. В UTF-8 не режем символ посередине:
  // отступаем к началу последнего символа.
  var utf8End = end;
  while (truncated && utf8End > start && (bytes[utf8End] & 0xC0) == 0x80) {
    utf8End--;
  }
  try {
    return TextPreview(
      utf8.decode(bytes.sublist(start, utf8End)),
      truncated: truncated,
    );
  } on FormatException {
    // Не UTF-8 — значит, Windows-1251.
  }
  return TextPreview(
    String.fromCharCodes([for (var i = start; i < end; i++) _cp1251(bytes[i])]),
    truncated: truncated,
  );
}

int _cp1251(int byte) {
  if (byte < 0x80) return byte;
  if (byte >= 0xC0) return 0x0410 + (byte - 0xC0); // А–я
  return _cp1251High[byte - 0x80];
}

/// Windows-1251, байты 0x80–0xBF.
const List<int> _cp1251High = [
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
  0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
  0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
  0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
  0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
  0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
];
