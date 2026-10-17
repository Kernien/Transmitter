import 'dart:convert';

import '../persistence/key_value_store.dart';
import 'reader_key.dart';
import 'reader_key_codec.dart';

/// Доски на устройстве и названия, которые читатель задал сам.
typedef StoredBoards = ({List<ReaderKey> keys, Set<String> customLabels});

/// Ключи читателя (публичные доски), сохранённые на этом устройстве.
///
/// Ключи — списком строк `TRM1R.…` (как в 0.7.0, чтобы и старые версии их
/// читали); отдельно — адреса досок, которые читатель переименовал сам:
/// их название от владельца не подменяет.
class ReaderKeyStore {
  const ReaderKeyStore(this._store, [this._codec = const ReaderKeyCodec()]);

  static const String _keysKey = 'reader_keys';
  static const String _customKey = 'reader_custom_labels';

  final SecureKeyValueStore _store;
  final ReaderKeyCodec _codec;

  Future<StoredBoards> loadAll() async {
    final keys = await _store.read(_keysKey);
    final custom = await _store.read(_customKey);
    return (
      keys: [
        if (keys != null)
          for (final code in (jsonDecode(keys) as List).cast<String>())
            _codec.decode(code),
      ],
      customLabels: {
        if (custom != null) ...(jsonDecode(custom) as List).cast<String>(),
      },
    );
  }

  Future<void> saveAll(List<ReaderKey> keys, Set<String> customLabels) async {
    await _store.write(
      _keysKey,
      jsonEncode([for (final k in keys) _codec.encode(k)]),
    );
    await _store.write(_customKey, jsonEncode(customLabels.toList()));
  }
}
