import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/utils/docx_text.dart';
import 'package:transmitter/domain/post.dart';

/// Минимальный .docx, как его сохраняет русский Word: id стиля заголовка
/// «1», а имя «heading 1» — в styles.xml.
Uint8List sampleDocx() {
  const document = '''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
  <w:p><w:pPr><w:pStyle w:val="1"/></w:pPr><w:r><w:t>Отчёт за неделю</w:t></w:r></w:p>
  <w:p>
    <w:r><w:t xml:space="preserve">Итог: </w:t></w:r>
    <w:r><w:rPr><w:b/></w:rPr><w:t>всё готово</w:t></w:r>
    <w:r><w:rPr><w:i/><w:b w:val="0"/></w:rPr><w:t xml:space="preserve"> вовремя</w:t></w:r>
  </w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>Пункт</w:t></w:r></w:p>
  <w:tbl>
    <w:tr><w:tc><w:p><w:r><w:t>Имя</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Сумма</w:t></w:r></w:p></w:tc></w:tr>
  </w:tbl>
</w:body>
</w:document>''';
  const styles = '''<?xml version="1.0" encoding="UTF-8"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="1"><w:name w:val="heading 1"/></w:style>
</w:styles>''';
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(document)))
    ..addFile(ArchiveFile.bytes('word/styles.xml', utf8.encode(styles)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('текст, заголовок, оформление, список и таблица из .docx', () {
    final paragraphs = parseDocx(sampleDocx());
    expect(paragraphs.map((p) => p.text), [
      'Отчёт за неделю',
      'Итог: всё готово вовремя',
      'Пункт',
      'Имя\tСумма',
    ]);
    expect(paragraphs[0].headingLevel, 1);
    expect(paragraphs[1].runs[1].bold, isTrue);
    expect(paragraphs[1].runs[2].bold, isFalse);
    expect(paragraphs[1].runs[2].italic, isTrue);
    expect(paragraphs[2].listItem, isTrue);
  });

  test('не документ Word — понятная ошибка', () {
    expect(() => parseDocx([1, 2, 3]), throwsFormatException);
    final zip = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile.bytes('x.txt', [1])),
    );
    expect(() => parseDocx(zip), throwsFormatException);
  });

  test('Markdown и .docx распознаются', () {
    Attachment file(String name, [String? mime]) =>
        Attachment(id: 'a', fileName: name, size: 1, mimeType: mime);
    expect(file('README.md').isMarkdown, isTrue);
    expect(file('README.md').isReadable, isTrue);
    expect(file('отчёт.DOCX').isDocx, isTrue);
    expect(file('отчёт.docx').isReadable, isTrue);
    expect(file('старый.doc').isReadable, isFalse);
    expect(file('книга.pdf').isReadable, isFalse);
  });
}
