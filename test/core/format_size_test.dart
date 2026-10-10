import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/utils/format_size.dart';

void main() {
  test('размеры файлов', () {
    expect(formatFileSize(0), '0 Б');
    expect(formatFileSize(512), '512 Б');
    expect(formatFileSize(1536), '1,5 КБ');
    expect(formatFileSize(150 * 1024), '150 КБ');
    expect(formatFileSize(25 * 1024 * 1024), '25,0 МБ');
    expect(formatFileSize(3 * 1024 * 1024 * 1024), '3,0 ГБ');
  });
}
