import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/files/openers/native_external_opener.dart';

void main() {
  Future<Directory> temp() async => Directory('/tmp');
  Future<Directory> cache() async => Directory('/home/u/.var/app/x/cache');

  test('на Linux копии для открытия — в кеше приложения, не в /tmp', () async {
    // Во Flatpak у песочницы свой /tmp: портал не открыл бы файл оттуда.
    final linux = await NativeExternalOpener.rootFor(
      isLinux: true,
      temporary: temp,
      cache: cache,
    );
    expect(linux.path, '/home/u/.var/app/x/cache/open');

    final other = await NativeExternalOpener.rootFor(
      isLinux: false,
      temporary: temp,
      cache: cache,
    );
    expect(other.path, '/tmp/open');
  });
}
