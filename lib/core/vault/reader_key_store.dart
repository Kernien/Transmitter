import 'dart:convert';

import '../persistence/key_value_store.dart';
import 'reader_key.dart';
import 'reader_key_codec.dart';

/// Ключи читателя (публичные доски), сохранённые на этом устройстве.
class ReaderKeyStore {
  const ReaderKeyStore(this._store, [this._codec = const ReaderKeyCodec()]);

  static const String _storeKey = 'reader_keys';

  final SecureKeyValueStore _store;
  final ReaderKeyCodec _codec;

  Future<List<ReaderKey>> loadAll() async {
    final raw = await _store.read(_storeKey);
    if (raw == null) return [];
    return [
      for (final code in (jsonDecode(raw) as List).cast<String>())
        _codec.decode(code),
    ];
  }

  Future<void> saveAll(List<ReaderKey> keys) => _store.write(
    _storeKey,
    jsonEncode([for (final k in keys) _codec.encode(k)]),
  );
}
