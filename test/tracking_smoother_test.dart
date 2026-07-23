import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/src/tracking/tracking_smoother.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

TrackingData _data({
  Offset leftEye = const Offset(0.6, 0.4),
  Offset rightEye = const Offset(0.4, 0.4),
  double confidence = 1.0,
  Offset? leftIris,
  Offset? rightIris,
}) {
  return TrackingData(
    boundingBox: const Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
    leftEye: leftEye,
    rightEye: rightEye,
    confidence: confidence,
    leftIris: leftIris,
    rightIris: rightIris,
  );
}

void main() {
  group('TrackingSmoother', () {
    test('first sample passes through unchanged', () {
      final smoother = TrackingSmoother();
      final data = _data();
      expect(smoother.smooth(data), same(data));
    });

    test('alpha=1.0 always returns the latest sample verbatim', () {
      final smoother = TrackingSmoother(alpha: 1.0);
      smoother.smooth(_data());
      final second = _data(leftEye: const Offset(0.9, 0.1));
      expect(smoother.smooth(second), same(second));
    });

    test('alpha=0.5 blends halfway between previous and current', () {
      final smoother = TrackingSmoother(alpha: 0.5);
      smoother.smooth(_data(leftEye: const Offset(0.0, 0.0)));
      final result = smoother.smooth(_data(leftEye: const Offset(1.0, 1.0)));
      expect(result.leftEye, const Offset(0.5, 0.5));
    });

    test('smoothing compounds across multiple frames', () {
      final smoother = TrackingSmoother(alpha: 0.5);
      // previous starts at 0.0; three frames all reporting 1.0.
      smoother.smooth(_data(leftEye: const Offset(0.0, 0.0)));
      final r1 = smoother.smooth(_data(leftEye: const Offset(1.0, 0.0)));
      expect(r1.leftEye.dx, closeTo(0.5, 1e-9));
      final r2 = smoother.smooth(_data(leftEye: const Offset(1.0, 0.0)));
      expect(r2.leftEye.dx, closeTo(0.75, 1e-9));
      final r3 = smoother.smooth(_data(leftEye: const Offset(1.0, 0.0)));
      expect(r3.leftEye.dx, closeTo(0.875, 1e-9));
    });

    test('reset() makes the next sample pass through unchanged', () {
      final smoother = TrackingSmoother(alpha: 0.5);
      smoother.smooth(_data(leftEye: const Offset(0.0, 0.0)));
      smoother.reset();
      final fresh = _data(leftEye: const Offset(1.0, 1.0));
      expect(smoother.smooth(fresh), same(fresh));
    });

    test('blends the bounding box and confidence', () {
      final smoother = TrackingSmoother(alpha: 0.5);
      const boxA = Rect.fromLTWH(0.0, 0.0, 0.2, 0.2);
      const boxB = Rect.fromLTWH(0.4, 0.4, 0.2, 0.2);
      smoother.smooth(
        TrackingData(
          boundingBox: boxA,
          leftEye: const Offset(0.6, 0.4),
          rightEye: const Offset(0.4, 0.4),
          confidence: 0.0,
        ),
      );
      final result = smoother.smooth(
        TrackingData(
          boundingBox: boxB,
          leftEye: const Offset(0.6, 0.4),
          rightEye: const Offset(0.4, 0.4),
          confidence: 1.0,
        ),
      );
      expect(result.boundingBox.left, closeTo(0.2, 1e-9));
      expect(result.boundingBox.top, closeTo(0.2, 1e-9));
      expect(result.confidence, closeTo(0.5, 1e-9));
    });

    test(
        'an optional landmark that appears snaps in rather than blending '
        'from nothing', () {
      final smoother = TrackingSmoother(alpha: 0.5);
      smoother.smooth(_data()); // no iris
      final withIris = _data(
        leftIris: const Offset(0.61, 0.4),
        rightIris: const Offset(0.39, 0.4),
      );
      final result = smoother.smooth(withIris);
      expect(result.leftIris, const Offset(0.61, 0.4));
      expect(result.rightIris, const Offset(0.39, 0.4));
    });

    test(
        'an optional landmark that disappears snaps to null rather than '
        'blending toward nothing', () {
      final smoother = TrackingSmoother(alpha: 0.5);
      smoother.smooth(
        _data(
          leftIris: const Offset(0.61, 0.4),
          rightIris: const Offset(0.39, 0.4),
        ),
      );
      final result = smoother.smooth(_data());
      expect(result.leftIris, isNull);
      expect(result.rightIris, isNull);
    });

    test('an optional landmark present in both frames blends normally', () {
      final smoother = TrackingSmoother(alpha: 0.5);
      smoother.smooth(_data(leftIris: const Offset(0.0, 0.0)));
      final result = smoother.smooth(_data(leftIris: const Offset(1.0, 1.0)));
      expect(result.leftIris, const Offset(0.5, 0.5));
    });

    test('rejects an out-of-range alpha', () {
      expect(() => TrackingSmoother(alpha: 0), throwsA(isA<AssertionError>()));
      expect(
        () => TrackingSmoother(alpha: 1.1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
