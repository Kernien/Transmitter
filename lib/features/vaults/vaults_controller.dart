import 'package:flutter/foundation.dart';

import '../../core/storage/cloud_provider_id.dart';
import '../../core/vault/reader_key.dart';
import '../../core/vault/reader_key_codec.dart';
import '../../core/vault/reader_key_store.dart';
import '../../core/vault/vault_key.dart';
import '../../core/vault/vault_key_codec.dart';
import '../../core/vault/vault_key_store.dart';
import '../../data/vault_settings.dart';

/// Ключи на этом устройстве: базы (владелец) и публичные доски (читатель).
/// Создание, импорт, переименование, удаление. Название и лимит размера
/// файла у базы общие для всех её устройств ([VaultSettingsRemote]).
class VaultsController extends ChangeNotifier {
  VaultsController(
    this._store, {
    this._readers,
    this._settings,
    this._codec = const VaultKeyCodec(),
    this._readerCodec = const ReaderKeyCodec(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final VaultKeyStore _store;
  final ReaderKeyStore? _readers;

  /// Настройки баз в облаке (название, лимит); `null` — только на устройстве.
  final VaultSettingsRemote? _settings;
  final DateTime Function() _clock;
  final VaultKeyCodec _codec;
  final ReaderKeyCodec _readerCodec;

  List<VaultKey> _vaults = const [];
  List<ReaderKey> _boards = const [];

  /// Адреса досок, которые читатель переименовал сам.
  Set<String> _customLabels = const {};

  List<VaultKey> get vaults => List.unmodifiable(_vaults);

  /// Публичные доски, которые на этом устройстве можно только читать.
  List<ReaderKey> get boards => List.unmodifiable(_boards);

  Future<void> load() async {
    _vaults = await _store.loadAll();
    final stored = await _readers?.loadAll();
    _boards = stored?.keys ?? const [];
    _customLabels = stored?.customLabels ?? const {};
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

  /// Новое название базы — на всех её устройствах: сначала в облако, потом
  /// сюда. Если записать в облако не удалось (например, оно не подключено),
  /// бросает ошибку облака и ничего не меняет.
  Future<void> rename(VaultKey key, String label) =>
      _change(key, (k) => k.copyWith(label: label.trim()));

  /// Новый лимит размера файла — так же, как [rename]. Уже загруженные
  /// файлы остаются, лимит действует для новых.
  Future<void> setMaxFileSize(VaultKey key, int maxFileSize) =>
      _change(key, (k) => k.copyWith(maxFileSize: maxFileSize));

  Future<void> _change(
    VaultKey key,
    VaultKey Function(VaultKey current) update,
  ) async {
    final next = update(_current(key) ?? key);
    await _settings?.saveSettings(
      next,
      VaultSettings(
        label: next.label,
        maxFileSize: next.maxFileSize,
        updatedAt: _clock().toUtc(),
      ),
    );
    await _replace(next);
  }

  /// Подтягивает настройки баз из облака: их могли поменять на другом
  /// устройстве. Базы без подключённого облака и ошибки сети пропускаются.
  Future<void> refreshSettings({VaultKey? only}) async {
    final settings = _settings;
    if (settings == null) return;
    for (final key in [..._vaults]) {
      if (only != null && !key.sameVaultAs(only)) continue;
      final VaultSettings? remote;
      try {
        remote = await settings.loadSettings(key);
      } catch (e) {
        debugPrint('Vault settings not refreshed: $e');
        continue;
      }
      // Ключ могли удалить или изменить, пока шёл запрос.
      final current = _current(key);
      if (remote == null || current == null || !remote.differsFrom(current)) {
        continue;
      }
      await _replace(
        current.copyWith(label: remote.label, maxFileSize: remote.maxFileSize),
      );
    }
  }

  VaultKey? _current(VaultKey key) =>
      _vaults.where((k) => k.sameVaultAs(key)).firstOrNull;

  Future<void> _replace(VaultKey next) =>
      _save([for (final k in _vaults) k.sameVaultAs(next) ? next : k]);

  /// Своё название доски: название от владельца его больше не меняет.
  Future<void> renameBoard(ReaderKey key, String label) => _saveBoards(
    [
      for (final k in _boards)
        k.sameBoardAs(key) ? k.copyWith(label: label.trim()) : k,
    ],
    customLabels: {..._customLabels, key.locator},
  );

  /// Текущее название доски на этом устройстве.
  String boardLabel(ReaderKey key) =>
      _boards.where((k) => k.sameBoardAs(key)).firstOrNull?.label ?? key.label;

  /// Владелец переименовал доску: название обновляется, если читатель не
  /// задал своё.
  Future<void> applyOwnerLabel(ReaderKey key, String ownerLabel) async {
    if (_customLabels.contains(key.locator)) return;
    final current = _boards.where((k) => k.sameBoardAs(key)).firstOrNull;
    if (current == null || current.label == ownerLabel) return;
    await _saveBoards([
      for (final k in _boards)
        k.sameBoardAs(key) ? k.copyWith(label: ownerLabel) : k,
    ]);
  }

  /// Удаляет ключ только с этого устройства. Данные в облаке остаются.
  Future<void> remove(VaultKey key) =>
      _save(_vaults.where((k) => !k.sameVaultAs(key)).toList());

  Future<void> removeBoard(ReaderKey key) => _saveBoards(
    _boards.where((k) => !k.sameBoardAs(key)).toList(),
    customLabels: _customLabels.difference({key.locator}),
  );

  Future<void> _save(List<VaultKey> next) async {
    await _store.saveAll(next);
    _vaults = next;
    notifyListeners();
  }

  Future<void> _saveBoards(
    List<ReaderKey> next, {
    Set<String>? customLabels,
  }) async {
    final readers = _readers;
    if (readers == null) throw StateError('Boards are not available');
    final custom = customLabels ?? _customLabels;
    await readers.saveAll(next, custom);
    _boards = next;
    _customLabels = custom;
    notifyListeners();
  }
}
