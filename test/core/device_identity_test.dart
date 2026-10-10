import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/core/device/device_identity.dart';
import 'package:transmitter/core/device/suggesters/native_device_name_suggester.dart';
import 'package:transmitter/core/persistence/key_value_store.dart';
import 'package:transmitter/core/utils/device_name.dart';

class FakeSuggester implements DeviceNameSuggester {
  FakeSuggester(this.result);

  final Future<String> Function() result;

  @override
  Future<String> suggest() => result();
}

void main() {
  late InMemoryKeyValueStore store;

  DeviceIdentity identity([Future<String> Function()? suggest]) =>
      DeviceIdentity(store, FakeSuggester(suggest ?? () async => 'Redmi 10'));

  setUp(() => store = InMemoryKeyValueStore());

  test('без имени — подпись платформой и предложение задать имя', () async {
    final d = identity();
    await d.load();
    expect(d.isNamed, isFalse);
    expect(d.name, currentDeviceName());
  });

  test('имя сохраняется и переживает перезапуск', () async {
    final d = identity();
    await d.load();
    await d.rename('  Redmi   —  рабочий ');
    expect(d.name, 'Redmi — рабочий');

    final restarted = identity();
    await restarted.load();
    expect(restarted.isNamed, isTrue);
    expect(restarted.name, 'Redmi — рабочий');
  });

  test('пустое имя не принимается, длинное обрезается', () async {
    final d = identity();
    expect(() => d.rename('   '), throwsArgumentError);
    await d.rename('x' * 100);
    expect(d.name, hasLength(DeviceIdentity.maxLength));
  });

  test(
    'подсказка: при ошибке или пустом ответе — название платформы',
    () async {
      expect(await identity().suggestName(), 'Redmi 10');
      expect(
        await identity(() async => throw Exception('нет канала')).suggestName(),
        currentDeviceName(),
      );
      expect(
        await identity(() async => '   ').suggestName(),
        currentDeviceName(),
      );
    },
  );

  test('подсказка для рабочего профиля Android', () {
    expect(
      AndroidDeviceNameSuggester.format(name: 'Redmi 10', workProfile: true),
      'Redmi 10 · рабочий',
    );
    expect(
      AndroidDeviceNameSuggester.format(name: 'Redmi 10', workProfile: false),
      'Redmi 10',
    );
  });
}
