import 'package:flutter/foundation.dart';

import '../persistence/key_value_store.dart';
import '../utils/device_name.dart';

/// Тексты подсказок по умолчанию (если язык интерфейса не передан).
String englishWorkProfileLabel() => 'work';
String englishBrowserName() => 'Browser';

/// Предлагает имя для этого устройства (например, «Redmi 10 · рабочий»).
abstract interface class DeviceNameSuggester {
  Future<String> suggest();
}

/// Имя этого устройства, которым подписываются новые записи.
///
/// Хранится только на устройстве. Пока пользователь его не задал, записи
/// подписываются названием платформы («Android», «Windows»…).
class DeviceIdentity extends ChangeNotifier {
  DeviceIdentity(this._store, this._suggester);

  static const String _storeKey = 'device_name';
  static const int maxLength = 40;

  final SecureKeyValueStore _store;
  final DeviceNameSuggester _suggester;
  String? _name;

  /// Задано ли имя пользователем (если нет — стоит предложить его задать).
  bool get isNamed => _name != null;

  String get name => _name ?? currentDeviceName();

  Future<void> load() async {
    final stored = await _store.read(_storeKey);
    _name = (stored == null || stored.trim().isEmpty) ? null : stored;
    notifyListeners();
  }

  /// Подсказка для поля ввода; при ошибке — название платформы.
  Future<String> suggestName() async {
    try {
      final suggestion = _normalize(await _suggester.suggest());
      return suggestion.isEmpty ? currentDeviceName() : suggestion;
    } catch (_) {
      return currentDeviceName();
    }
  }

  /// Сохраняет имя. Пустое имя не принимается.
  Future<void> rename(String name) async {
    final normalized = _normalize(name);
    if (normalized.isEmpty) {
      throw ArgumentError('Device name must not be empty');
    }
    await _store.write(_storeKey, normalized);
    _name = normalized;
    notifyListeners();
  }

  static String _normalize(String name) {
    final collapsed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.length <= maxLength
        ? collapsed
        : collapsed.substring(0, maxLength);
  }
}
