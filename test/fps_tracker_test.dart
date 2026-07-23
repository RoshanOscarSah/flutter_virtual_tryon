import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/src/tracking/fps_tracker.dart';

void main() {
  group('FpsTracker', () {
    test('first tick returns null (no prior sample)', () {
      final tracker = FpsTracker();
      expect(tracker.tick(DateTime(2026)), isNull);
    });

    test('reports 1 / elapsed-seconds between ticks', () {
      final tracker = FpsTracker();
      final start = DateTime(2026);
      tracker.tick(start);
      final fps = tracker.tick(start.add(const Duration(milliseconds: 500)));
      expect(fps, closeTo(2.0, 1e-9));
    });

    test('a later tick measures against the previous tick, not the first', () {
      final tracker = FpsTracker();
      final start = DateTime(2026);
      tracker.tick(start);
      tracker.tick(start.add(const Duration(milliseconds: 500)));
      final fps = tracker.tick(start.add(const Duration(milliseconds: 600)));
      expect(fps, closeTo(10.0, 1e-9));
    });

    test('returns null when the clock does not advance', () {
      final tracker = FpsTracker();
      final now = DateTime(2026);
      tracker.tick(now);
      expect(tracker.tick(now), isNull);
    });

    test('returns null when the clock goes backwards', () {
      final tracker = FpsTracker();
      final now = DateTime(2026);
      tracker.tick(now);
      expect(
          tracker.tick(now.subtract(const Duration(milliseconds: 10))), isNull);
    });
  });
}
