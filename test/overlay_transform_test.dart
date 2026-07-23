import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/src/renderer/overlay_transform.dart';

TrackingData _data({
  Offset leftEye = const Offset(0.6, 0.4),
  Offset rightEye = const Offset(0.4, 0.4),
}) {
  return TrackingData(
    boundingBox: const Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
    leftEye: leftEye,
    rightEye: rightEye,
    confidence: 1.0,
  );
}

void main() {
  group('OverlayPlacement.forImage', () {
    test('centers on the eye midpoint in local pixels', () {
      final placement = OverlayPlacement.forImage(
        tracking: _data(),
        viewSize: const Size(1000, 800),
      );
      // eyeCenter = (0.5, 0.4) normalized -> (500, 320) pixels.
      expect(placement.center, const Offset(500, 320));
    });

    test('sizes from the pixel-space eye distance, not the normalized one', () {
      // A wide, short view: eye distance is 0.2 normalized width but the
      // view is 2000 wide x 200 tall, so pixel eye distance is 400, not
      // something blended with the tiny height.
      final placement = OverlayPlacement.forImage(
        tracking: _data(),
        viewSize: const Size(2000, 200),
        eyeDistanceMultiplier: 1.0,
        scaleMultiplier: 1.0,
      );
      expect(placement.width, closeTo(400, 1e-6));
    });

    test('eyeDistanceMultiplier and scaleMultiplier both scale width', () {
      final base = OverlayPlacement.forImage(
        tracking: _data(),
        viewSize: const Size(1000, 1000),
        eyeDistanceMultiplier: 2.0,
        scaleMultiplier: 1.0,
      );
      final scaled = OverlayPlacement.forImage(
        tracking: _data(),
        viewSize: const Size(1000, 1000),
        eyeDistanceMultiplier: 2.0,
        scaleMultiplier: 1.5,
      );
      expect(scaled.width, closeTo(base.width * 1.5, 1e-9));
    });

    test('offsetPixels nudges the center directly', () {
      final placement = OverlayPlacement.forImage(
        tracking: _data(),
        viewSize: const Size(1000, 800),
        offsetPixels: const Offset(10, -5),
      );
      expect(placement.center, const Offset(510, 315));
    });

    test('rotation is zero for level eyes', () {
      final placement = OverlayPlacement.forImage(
        tracking: _data(),
        viewSize: const Size(1000, 800),
      );
      expect(placement.rotation, closeTo(0, 1e-9));
    });

    test('rotation matches the pixel-space eye vector on a non-square view',
        () {
      // Eyes tilted in normalized space; view is non-square, so the
      // correct pixel-space angle differs from the naive normalized-space
      // atan2 that TrackingData.rotationRadians would give.
      final tilted = _data(
        rightEye: const Offset(0.4, 0.40),
        leftEye: const Offset(0.6, 0.44),
      );
      const viewSize = Size(1000, 300);
      final placement = OverlayPlacement.forImage(
        tracking: tilted,
        viewSize: viewSize,
      );

      final leftPx = Offset(0.6 * 1000, 0.44 * 300);
      final rightPx = Offset(0.4 * 1000, 0.40 * 300);
      final expected = math.atan2(
        leftPx.dy - rightPx.dy,
        leftPx.dx - rightPx.dx,
      );
      expect(placement.rotation, closeTo(expected, 1e-9));
      // And confirm it's meaningfully different from the normalized-space
      // value, proving the pixel-space fix actually matters here.
      expect(placement.rotation, isNot(closeTo(tilted.rotationRadians, 1e-3)));
    });

    test('rotationOffsetRadians adds on top', () {
      final placement = OverlayPlacement.forImage(
        tracking: _data(),
        viewSize: const Size(1000, 800),
        rotationOffsetRadians: 0.25,
      );
      expect(placement.rotation, closeTo(0.25, 1e-9));
    });
  });

  group('OverlayPlacement.forPoint', () {
    test('centers on the given anchor, not the eye midpoint', () {
      final placement = OverlayPlacement.forPoint(
        tracking: _data(),
        viewSize: const Size(1000, 800),
        anchorNormalized: const Offset(0.61, 0.41), // e.g. a left iris
        sizeRatio: 1.0,
      );
      expect(placement.center, const Offset(610, 328));
    });

    test('sizes from the eye-pair distance, not the anchor', () {
      // Same anchor, different eye separation -> different size, proving
      // size tracks the whole face, not just the single anchor point.
      final close = OverlayPlacement.forPoint(
        tracking: _data(leftEye: const Offset(0.55, 0.4)), // narrower
        viewSize: const Size(1000, 800),
        anchorNormalized: const Offset(0.6, 0.4),
        sizeRatio: 1.0,
      );
      final wide = OverlayPlacement.forPoint(
        tracking: _data(leftEye: const Offset(0.7, 0.4)), // wider
        viewSize: const Size(1000, 800),
        anchorNormalized: const Offset(0.6, 0.4),
        sizeRatio: 1.0,
      );
      expect(wide.width, greaterThan(close.width));
    });

    test('sizeRatio and scaleMultiplier both scale width', () {
      final base = OverlayPlacement.forPoint(
        tracking: _data(),
        viewSize: const Size(1000, 1000),
        anchorNormalized: const Offset(0.6, 0.4),
        sizeRatio: 0.2,
      );
      final scaled = OverlayPlacement.forPoint(
        tracking: _data(),
        viewSize: const Size(1000, 1000),
        anchorNormalized: const Offset(0.6, 0.4),
        sizeRatio: 0.2,
        scaleMultiplier: 2.0,
      );
      expect(scaled.width, closeTo(base.width * 2.0, 1e-9));
    });

    test('rotation matches the eye-pair pixel-space angle', () {
      final tilted = _data(
        rightEye: const Offset(0.4, 0.40),
        leftEye: const Offset(0.6, 0.44),
      );
      final placement = OverlayPlacement.forPoint(
        tracking: tilted,
        viewSize: const Size(1000, 800),
        anchorNormalized: const Offset(0.6, 0.44),
        sizeRatio: 1.0,
      );
      final glasses = OverlayPlacement.forImage(
        tracking: tilted,
        viewSize: const Size(1000, 800),
      );
      // Same eyes, same view -> same head-roll angle regardless of which
      // placement method computed it.
      expect(placement.rotation, closeTo(glasses.rotation, 1e-9));
    });
  });

  group('OverlayPlacement.heightFor', () {
    test('divides width by aspect ratio', () {
      const placement = OverlayPlacement(
        center: Offset.zero,
        width: 200,
        rotation: 0,
      );
      expect(placement.heightFor(2.0), closeTo(100, 1e-9));
    });

    test('falls back to width for a non-positive aspect ratio', () {
      const placement = OverlayPlacement(
        center: Offset.zero,
        width: 200,
        rotation: 0,
      );
      expect(placement.heightFor(0), 200);
      expect(placement.heightFor(-1), 200);
    });
  });
}
