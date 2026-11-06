import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/domain/transfer_progress.dart';

void main() {
  group('TransferProgress', () {
    test('рассчитывает долю и процент корректно', () {
      const p1 = TransferProgress(
        transferred: 50,
        total: 100,
        bytesPerSecond: 1000,
      );
      expect(p1.fraction, 0.5);
      expect(p1.percent, 50);

      const pZero = TransferProgress(
        transferred: 0,
        total: 0,
        bytesPerSecond: 0,
      );
      expect(pZero.fraction, 0.0);
      expect(pZero.percent, 0);

      const pClamp = TransferProgress(
        transferred: 150,
        total: 100,
        bytesPerSecond: 0,
      );
      expect(pClamp.fraction, 1.0);
      expect(pClamp.percent, 100);
    });
  });

  group('TransferTracker', () {
    test('рассчитывает скорость и обновляет прогресс', () {
      var now = DateTime(2026, 11, 6, 10, 0, 0);
      final tracker = TransferTracker(clock: () => now);

      final p0 = tracker.update(0, 1000);
      expect(p0.transferred, 0);
      expect(p0.total, 1000);
      expect(p0.bytesPerSecond, 0);

      // Прошло 500 мс, передано 500 байт -> скорость 1000 Б/с
      now = now.add(const Duration(milliseconds: 500));
      final p1 = tracker.update(500, 1000);
      expect(p1.transferred, 500);
      expect(p1.fraction, 0.5);
      expect(p1.bytesPerSecond, closeTo(1000, 1));

      // Ещё 500 мс, передано ещё 500 байт (всего 1000) -> EMA сглаживает скорость
      now = now.add(const Duration(milliseconds: 500));
      final p2 = tracker.update(1000, 1000);
      expect(p2.transferred, 1000);
      expect(p2.fraction, 1.0);
      expect(p2.percent, 100);
      expect(p2.bytesPerSecond, greaterThan(0));
    });
  });
}
