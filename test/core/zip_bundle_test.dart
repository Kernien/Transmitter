import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/files/zip_bundle.dart';

void main() {
  test('архив распаковывается обратно, одинаковые имена не теряются', () async {
    final zip = await buildZip([
      BundleEntry('фото.jpg', Uint8List.fromList([1, 2, 3])),
      BundleEntry('фото.jpg', Uint8List.fromList([4, 5])),
      BundleEntry('ФОТО.jpg', Uint8List.fromList([6])),
      BundleEntry('a/b:c.txt', Uint8List.fromList([7])),
    ]);

    final archive = ZipDecoder().decodeBytes(zip);
    final files = {for (final f in archive) f.name: f.content.toList()};
    expect(files, {
      'фото.jpg': [1, 2, 3],
      'фото (2).jpg': [4, 5],
      'ФОТО (3).jpg': [6],
      'a_b_c.txt': [7],
    });
  });
}
