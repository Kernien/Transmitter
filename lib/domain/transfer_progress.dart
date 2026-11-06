import '../core/utils/clock.dart';

/// Прогресс передачи файла (загрузка в облако или скачивание на устройство).
class TransferProgress {
  const TransferProgress({
    required this.transferred,
    required this.total,
    required this.bytesPerSecond,
  });

  /// Переданное количество байт.
  final int transferred;

  /// Общий размер файла в байтах.
  final int total;

  /// Текущая скорость передачи (байт/с).
  final double bytesPerSecond;

  /// Доля переданного от 0.0 до 1.0.
  double get fraction =>
      total > 0 ? (transferred / total).clamp(0.0, 1.0) : 0.0;

  /// Процент переданного (0..100).
  int get percent => (fraction * 100).toInt();
}

/// Расчёт сглаженной скорости передачи и оставшегося времени.
class TransferTracker {
  TransferTracker({this.clock = DateTime.now});

  final Clock clock;
  DateTime? _startTime;
  DateTime? _lastTime;
  int _lastBytes = 0;
  double _speed = 0.0;

  TransferProgress update(int transferred, int total) {
    final now = clock();
    _startTime ??= now;
    if (_lastTime == null) {
      _lastTime = now;
      _lastBytes = transferred;
      return TransferProgress(
        transferred: transferred,
        total: total,
        bytesPerSecond: 0,
      );
    }

    final dt = now.difference(_lastTime!).inMilliseconds / 1000.0;
    if (dt >= 0.15) {
      final instantSpeed = (transferred - _lastBytes) / dt;
      // Экспоненциальное скользящее среднее для плавного отображения скорости.
      _speed = _speed == 0.0 ? instantSpeed : _speed * 0.7 + instantSpeed * 0.3;
      _lastTime = now;
      _lastBytes = transferred;
    } else if (_speed == 0.0 && transferred > 0) {
      final totalDt = now.difference(_startTime!).inMilliseconds / 1000.0;
      if (totalDt > 0) _speed = transferred / totalDt;
    }

    return TransferProgress(
      transferred: transferred,
      total: total,
      bytesPerSecond: _speed > 0 ? _speed : 0,
    );
  }
}
