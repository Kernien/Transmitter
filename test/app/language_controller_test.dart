import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/app/language_controller.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';

void main() {
  late InMemoryKeyValueStore store;
  var system = [const Locale('ru', 'RU')];

  LanguageController controller() =>
      LanguageController(store, systemLocales: () => system);

  setUp(() {
    store = InMemoryKeyValueStore();
    system = [const Locale('ru', 'RU')];
  });

  test('по умолчанию — как в системе', () async {
    final c = controller();
    await c.load();
    expect(c.language, AppLanguage.system);
    expect(c.locale, isNull);
    expect(c.current.localeName, 'ru');

    system = [const Locale('de')];
    expect(c.current.localeName, 'en', reason: 'немецкой системе — английский');
  });

  test('выбранный язык важнее системного и переживает перезапуск', () async {
    final c = controller();
    await c.load();
    await c.select(AppLanguage.en);
    expect(c.locale, const Locale('en'));
    expect(c.current.localeName, 'en');
    expect(c.current.save, 'Save');

    final restarted = controller();
    await restarted.load();
    expect(restarted.language, AppLanguage.en);
  });

  test('возврат к системному языку', () async {
    final c = controller();
    await c.select(AppLanguage.en);
    await c.select(AppLanguage.system);
    expect(c.locale, isNull);
    expect(c.current.localeName, 'ru');
  });

  test('неизвестное значение в хранилище — как в системе', () async {
    await store.write('ui_language', 'klingon');
    final c = controller();
    await c.load();
    expect(c.language, AppLanguage.system);
  });
}
