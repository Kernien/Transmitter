import 'package:flutter/foundation.dart';

import '../../core/storage/cloud_provider_id.dart';
import '../../core/vault/reader_key.dart';
import '../../core/vault/reader_key_codec.dart';
import '../../core/vault/reader_key_store.dart';
import '../../core/vault/vault_key.dart';
import '../../core/vault/vault_key_codec.dart';
import '../../core/vault/vault_key_store.dart';

/// Ключи на этом устройстве: базы (владелец) и публичные доски (читатель).
/// Создание, импорт, переименование, удаление.
class VaultsController extends ChangeNotifier {
  VaultsController(
    this._store, {
    this._readers,
    this._codec = const VaultKeyCodec(),
    this._readerCodec = const ReaderKeyCodec(),
  });

  final VaultKeyStore _store;
  final ReaderKeyStore? _readers;
  final VaultKeyCodec _codec;
  final ReaderKeyCodec _readerCodec;

  List<VaultKey> _vaults = const [];
  List<ReaderKey> _boards = const [];

  List<VaultKey> get vaults => List.unmodifiable(_vaults);

  /// Публичные доски, которые на этом устройстве можно только читать.
  List<ReaderKey> get boards => List.unmodifiable(_boards);

  Future<void> load() async {
    _vaults = await _store.loadAll();
    _boards = await _readers?.loadAll() ?? const [];
    notifyListeners();
  }

  Future<VaultKey> create({
    required String label,
    required CloudProviderId provider,
    int maxFileSize = VaultKey.defaultMaxFileSize,
  }) async {
    final key = VaultKey.generate(
      provider: provider,
      label: label.trim(),
      maxFileSize: maxFileSize,
    );
    await _save([..._vaults, key]);
    return key;
  }

  /// Добавляет ключ базы из строки или QR-кода. Если такой ключ уже есть,
  /// возвращает существующий. Бросает [FormatException] для неверной строки.
  Future<VaultKey> importCode(String code) async {
    final key = _codec.decode(code);
    for (final existing in _vaults) {
      if (existing.sameVaultAs(key)) return existing;
    }
    await _save([..._vaults, key]);
    return key;
  }

  /// Добавляет ключ базы ([VaultKey]) или ключ читателя ([ReaderKey]) —
  /// какой из них, видно по строке.
  Future<Object> importAny(String code) async {
    if (!ReaderKeyCodec.looksLikeReaderKey(code)) return importCode(code);
    final key = _readerCodec.decode(code);
    for (final existing in _boards) {
      if (existing.sameBoardAs(key)) return existing;
    }
    await _saveBoards([..._boards, key]);
    return key;
  }

  String exportCode(VaultKey key) => _codec.encode(key);

  String exportBoardCode(ReaderKey key) => _readerCodec.encode(key);

  Future<void> rename(VaultKey key, String label) => _save([
    for (final k in _vaults)
      k.sameVaultAs(key) ? k.copyWith(label: label.trim()) : k,
  ]);

  Future<void> renameBoard(ReaderKey key, String label) => _saveBoards([
    for (final k in _boards)
      k.sameBoardAs(key) ? k.copyWith(label: label.trim()) : k,
  ]);

  /// Удаляет ключ только с этого устройства. Данные в облаке остаются.
  Future<void> remove(VaultKey key) =>
      _save(_vaults.where((k) => !k.sameVaultAs(key)).toList());

  Future<void> removeBoard(ReaderKey key) =>
      _saveBoards(_boards.where((k) => !k.sameBoardAs(key)).toList());

  Future<void> _save(List<VaultKey> next) async {
    await _store.saveAll(next);
    _vaults = next;
    notifyListeners();
  }

  Future<void> _saveBoards(List<ReaderKey> next) async {
    final readers = _readers;
    if (readers == null) throw StateError('Boards are not available');
    await readers.saveAll(next);
    _boards = next;
    notifyListeners();
  }
}
