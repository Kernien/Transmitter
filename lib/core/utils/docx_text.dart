import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Кусок текста с одинаковым оформлением.
class DocxRun {
  const DocxRun(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;
}

/// Абзац документа Word.
class DocxParagraph {
  const DocxParagraph(
    this.runs, {
    this.headingLevel = 0,
    this.listItem = false,
  });

  final List<DocxRun> runs;

  /// 1–6 — заголовок (стили «Заголовок 1…6» / Heading 1…6), 0 — обычный.
  final int headingLevel;

  /// Пункт списка (маркированного или нумерованного).
  final bool listItem;

  String get text => runs.map((r) => r.text).join();
}

/// Текст документа `.docx` без картинок и вёрстки: абзацы, заголовки,
/// списки, таблицы (ячейки через табуляцию), жирный и курсив.
///
/// `.docx` — zip-архив; текст лежит в `word/document.xml`. Бросает
/// [FormatException], если файл не похож на документ Word.
List<DocxParagraph> parseDocx(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const FormatException('Not a .docx file');
  }
  final entry = archive.findFile('word/document.xml');
  if (entry == null) throw const FormatException('Not a .docx file');
  final document = XmlDocument.parse(utf8.decode(entry.content));
  final body = document.findAllElements('w:body').firstOrNull;
  if (body == null) return const [];
  final headings = _headingStyles(archive);

  final paragraphs = <DocxParagraph>[];
  for (final block in body.childElements) {
    switch (block.name.qualified) {
      case 'w:p':
        paragraphs.add(_paragraph(block, headings));
      case 'w:tbl':
        for (final row in block.findAllElements('w:tr')) {
          final cells = [
            for (final cell in row.findElements('w:tc'))
              cell
                  .findAllElements('w:p')
                  .map((p) => _paragraph(p, headings).text)
                  .where((t) => t.isNotEmpty)
                  .join(' '),
          ];
          paragraphs.add(DocxParagraph([DocxRun(cells.join('\t'))]));
        }
    }
  }
  return paragraphs;
}

/// Уровни заголовков по id стиля. В файле абзац ссылается на id стиля, а
/// он зависит от языка Word («Heading1», в русском — например «1»);
/// настоящее имя («heading 1») — в `word/styles.xml`.
Map<String, int> _headingStyles(Archive archive) {
  final levels = <String, int>{};
  final entry = archive.findFile('word/styles.xml');
  if (entry != null) {
    try {
      final styles = XmlDocument.parse(utf8.decode(entry.content));
      for (final style in styles.findAllElements('w:style')) {
        final id = style.getAttribute('w:styleId');
        final name = style.getElement('w:name')?.getAttribute('w:val') ?? '';
        final level = _headingLevel(name);
        if (id != null && level > 0) levels[id] = level;
      }
    } on Object {
      // Без стилей заголовки определятся по id.
    }
  }
  return levels;
}

int _headingLevel(String name) {
  final match = RegExp(
    r'(?:heading|заголовок)\s*(\d)',
    caseSensitive: false,
  ).firstMatch(name);
  return match == null ? 0 : int.parse(match.group(1)!);
}

DocxParagraph _paragraph(XmlElement p, Map<String, int> headings) {
  final properties = p.getElement('w:pPr');
  final style = properties?.getElement('w:pStyle')?.getAttribute('w:val') ?? '';
  final headingLevel = headings[style] ?? _headingLevel(style);
  final runs = <DocxRun>[];
  for (final run in p.findAllElements('w:r')) {
    final format = run.getElement('w:rPr');
    final bold = _isOn(format?.getElement('w:b'));
    final italic = _isOn(format?.getElement('w:i'));
    final text = StringBuffer();
    for (final part in run.childElements) {
      switch (part.name.qualified) {
        case 'w:t':
          text.write(part.innerText);
        case 'w:tab':
          text.write('\t');
        case 'w:br' || 'w:cr':
          text.write('\n');
      }
    }
    if (text.isNotEmpty) {
      runs.add(DocxRun(text.toString(), bold: bold, italic: italic));
    }
  }
  return DocxParagraph(
    runs,
    headingLevel: headingLevel,
    listItem: properties?.getElement('w:numPr') != null,
  );
}

/// `<w:b/>` включает свойство, `<w:b w:val="0"/>` — выключает.
bool _isOn(XmlElement? flag) {
  if (flag == null) return false;
  final value = flag.getAttribute('w:val');
  return value == null || (value != '0' && value != 'false');
}
