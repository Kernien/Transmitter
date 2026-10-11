import 'dart:convert';
import 'dart:io';

import 'key_value_store.dart';

/// Хранилище строк в JSON-файле, доступном только текущему пользователю
/// (папка 700, файл 600).
///
/// Для Linux: системная «связка ключей» (Secret Service) есть не везде —
/// например, в игровом режиме Steam Deck её нет, — а ключи баз должны быть
/// доступны всегда. Так же хранят токены gh, rclone и другие программы.
class FileKeyValueStore implements SecureKeyValueStore {
  FileKeyValueStore(this.file, {bool? restrictPermissions})
    : _restrictPermissions =
          restrictPermissions ?? (Platform.isLinux || Platform.isMacOS);

  /// Файл по стандарту XDG: `~/.local/share/<appId>/secure_store.json`.
  factory FileKeyValueStore.xdg(String appId) {
    final env = Platform.environment;
    final dataHome = env['XDG_DATA_HOME']?.isNotEmpty == true
        ? env['XDG_DATA_HOME']!
        : '${env['HOME']}/.local/share';
    return FileKeyValueStore(File('$dataHome/$appId/secure_store.json'));
  }

  final File file;
  final bool _restrictPermissions;
  Map<String, String>? _values;

  /// Записи идут по очереди, чтобы одновременные изменения не потерялись.
  Future<void> _queue = Future.value();

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String value) =>
      _update((values) => values[key] = value);

  @override
  Future<void> delete(String key) => _update((values) => values.remove(key));

  Future<void> _update(void Function(Map<String, String> values) change) {
    final next = _queue.then((_) async {
      final values = await _load();
      change(values);
      await _save(values);
    });
    _queue = next.catchError((_) {});
    return next;
  }

  Future<Map<String, String>> _load() async {
    final cached = _values;
    if (cached != null) return cached;
    if (!await file.exists()) return _values = {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      return _values = (decoded as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
    } on Object {
      // Повреждённый файл не должен мешать запуску: откладываем его в
      // сторону (его можно восстановить вручную) и начинаем с пустого.
      await file.rename('${file.path}.broken');
      return _values = {};
    }
  }

  /// Пишем во временный файл и переименовываем: при сбое посреди записи
  /// старое содержимое остаётся целым.
  Future<void> _save(Map<String, String> values) async {
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _chmod('700', dir.path);
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsString('', flush: true);
    await _chmod('600', temp.path);
    await temp.writeAsString(jsonEncode(values), flush: true);
    await temp.rename(file.path);
  }

  Future<void> _chmod(String mode, String path) async {
    if (_restrictPermissions) await Process.run('chmod', [mode, path]);
  }
}
