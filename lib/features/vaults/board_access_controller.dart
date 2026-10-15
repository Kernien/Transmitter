import 'package:flutter/foundation.dart';

import '../../core/vault/reader_key_codec.dart';
import '../../data/board_publisher.dart';

enum BoardAccessStatus {
  loading,

  /// Доступ на чтение не открыт.
  closed,

  /// Доступ открыт, есть ключ читателя.
  open,

  /// Облако не умеет открывать файлы по ссылке.
  unsupported,

  /// Не удалось узнать состояние (см. [BoardAccessController.error]).
  failed,
}

/// Окно «Доступ на чтение» для одной базы: открыть доступ, показать ключ
/// читателя, закрыть доступ.
class BoardAccessController extends ChangeNotifier {
  BoardAccessController({
    required this._publisher,
    required this._label,
    this._codec = const ReaderKeyCodec(),
  });

  /// Открывает управление доской; `null` — облако не умеет ссылки.
  final Future<BoardPublisher?> Function() _publisher;
  final String _label;
  final ReaderKeyCodec _codec;

  BoardPublisher? _board;
  BoardAccessStatus _status = BoardAccessStatus.loading;
  bool _busy = false;
  String? _readerCode;
  Object? _error;
  bool _disposed = false;

  BoardAccessStatus get status => _status;

  /// Идёт открытие или закрытие доступа.
  bool get isBusy => _busy;

  /// Ключ читателя строкой (`TRM1R.…`), когда доступ открыт.
  String? get readerCode => _readerCode;

  /// Последняя ошибка; текст — `describeError`.
  Object? get error => _error;

  Future<void> load() async {
    _status = BoardAccessStatus.loading;
    _error = null;
    _notify();
    try {
      final board = _board ??= await _publisher();
      if (board == null) {
        _status = BoardAccessStatus.unsupported;
      } else {
        final state = await board.state(refresh: true);
        _readerCode = state == null
            ? null
            : _codec.encode(board.readerKeyFor(state));
        _status = state == null
            ? BoardAccessStatus.closed
            : BoardAccessStatus.open;
      }
    } catch (e) {
      _error = e;
      _status = BoardAccessStatus.failed;
    }
    _notify();
  }

  /// Возвращает `true`, если доступ открыт.
  Future<bool> openAccess() => _run(() async {
    final key = await _board!.open(label: _label);
    _readerCode = _codec.encode(key);
    _status = BoardAccessStatus.open;
  });

  /// Возвращает `true`, если доступ закрыт.
  Future<bool> closeAccess() => _run(() async {
    await _board!.close();
    _readerCode = null;
    _status = BoardAccessStatus.closed;
  });

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy || _board == null) return false;
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
