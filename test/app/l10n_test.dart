import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transmitter/app/l10n.dart';
import 'package:transmitter/core/auth/auth_browser.dart';
import 'package:transmitter/core/errors/app_error.dart';
import 'package:transmitter/core/files/file_transfer_service.dart';
import 'package:transmitter/core/storage/cloud_storage.dart';
import 'package:transmitter/core/vault/vault_key_codec.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  Set<String> keys(String file) =>
      (jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>).keys
          .where((k) => !k.startsWith('@'))
          .toSet();

  test('в русском и английском файлах одинаковый набор строк', () {
    final enKeys = keys('lib/l10n/app_en.arb');
    final ruKeys = keys('lib/l10n/app_ru.arb');
    expect(ruKeys.difference(enKeys), isEmpty, reason: 'лишние в app_ru.arb');
    expect(
      enKeys.difference(ruKeys),
      isEmpty,
      reason: 'не переведены в app_ru.arb',
    );
  });

  test('у каждого кода ошибки есть текст на обоих языках', () {
    for (final code in ErrorCode.values) {
      final error = StorageException(code, {
        'provider': 'Dropbox',
        'details': '500',
        'port': '47819',
        'maxBytes': 25 * 1024 * 1024,
        'path': 'a/b',
      });
      for (final l in [ru, en]) {
        final text = l.describeError(error);
        expect(text, isNotEmpty, reason: '${l.localeName}: $code');
        expect(text, isNot(contains('{')), reason: '${l.localeName}: $code');
      }
    }
  });

  test('тексты ошибок на нужном языке', () {
    const tooLarge = FileTooLargeException(30 << 20, 25 << 20);
    expect(ru.describeError(tooLarge), 'Файл больше 25 МБ');
    expect(en.describeError(tooLarge), 'File is larger than 25 MB');

    expect(ru.describeError(const AuthCancelledException()), 'Вход отменён');
    expect(
      en.describeError(const InvalidVaultKeyException(ErrorCode.keyCorrupted)),
      'The key is damaged',
    );
    expect(
      ru.describeError(const FileError('big.iso', tooLarge)),
      'big.iso: Файл больше 25 МБ',
    );
    expect(en.describeError(StateError('x')), startsWith('Error: '));
    // Нет сети — понятный текст вместо технического.
    expect(
      ru.describeError(http.ClientException('Network is unreachable')),
      'Нет связи — проверьте интернет и попробуйте ещё раз',
    );
    expect(
      en.describeError(TimeoutException('slow')),
      startsWith('No connection'),
    );
  });

  test('размеры файлов по правилам языка', () {
    expect(ru.fileSize(512), '512 Б');
    expect(ru.fileSize(1536), '1,5 КБ');
    expect(en.fileSize(1536), '1.5 KB');
    expect(en.fileSize(150 * 1024), '150 KB');
    expect(ru.fileSize(25 * 1024 * 1024), '25,0 МБ');
    expect(en.sizeLimitOf(100 * 1024 * 1024), '100 MB');
  });

  test('неподдерживаемый язык системы — английский', () {
    final resolved = basicLocaleListResolution([
      const Locale('de', 'DE'),
    ], AppLocalizations.supportedLocales);
    expect(lookupAppLocalizations(resolved).localeName, 'en');
  });
}
