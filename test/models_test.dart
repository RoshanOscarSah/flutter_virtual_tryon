import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

TrackingData _data({
  Offset leftEye = const Offset(0.6, 0.4),
  Offset rightEye = const Offset(0.4, 0.4),
  Rect boundingBox = const Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
  double confidence = 0.9,
  Offset? leftIris,
  Offset? rightIris,
}) {
  return TrackingData(
    boundingBox: boundingBox,
    leftEye: leftEye,
    rightEye: rightEye,
    confidence: confidence,
    leftIris: leftIris,
    rightIris: rightIris,
  );
}

void main() {
  group('TrackingData derived values', () {
    test('eyeCenter is the midpoint of the eyes', () {
      expect(_data().eyeCenter, const Offset(0.5, 0.4));
    });

    test('rotation is 0 degrees for level eyes', () {
      // Subject's left eye is on the frame's right in an unmirrored image,
      // so a level face has rightEye -> leftEye pointing in +x.
      expect(_data().rotation, closeTo(0, 1e-9));
    });

    test('rotation reports head roll in degrees', () {
      // Subject's left eye 0.1 lower than their right, eyes 0.2 apart
      // horizontally: atan2(0.1, 0.2) = 26.565° clockwise.
      final tilted = _data(
        rightEye: const Offset(0.4, 0.4),
        leftEye: const Offset(0.6, 0.5),
      );
      expect(tilted.rotation, closeTo(26.565051177077994, 1e-9));

      // Mirror-image tilt reads counter-clockwise (negative).
      final opposite = _data(
        rightEye: const Offset(0.4, 0.5),
        leftEye: const Offset(0.6, 0.4),
      );
      expect(opposite.rotation, closeTo(-26.565051177077994, 1e-9));
    });

    test('faceCenter, faceWidth, faceHeight come from the bounding box', () {
      final d = _data();
      expect(d.faceCenter, const Offset(0.5, 0.5));
      expect(d.faceWidth, closeTo(0.4, 1e-9));
      expect(d.faceHeight, closeTo(0.5, 1e-9));
    });

    test('translation is offset from frame center', () {
      final d = _data(boundingBox: const Rect.fromLTWH(0.5, 0.5, 0.4, 0.4));
      expect(d.translation.dx, closeTo(0.2, 1e-9));
      expect(d.translation.dy, closeTo(0.2, 1e-9));
    });

    test('scale equals eye distance', () {
      expect(_data().scale, closeTo(0.2, 1e-9));
    });

    test('value equality', () {
      expect(_data(), equals(_data()));
      expect(_data().hashCode, equals(_data().hashCode));
      expect(_data(confidence: 0.5), isNot(equals(_data())));
    });

    test('toString is a readable summary, not the default Instance of...', () {
      final text = _data().toString();
      expect(text, startsWith('TrackingData(box: '));
      expect(text, contains('eyes: '));
      expect(text, contains('confidence: 0.90)'));
    });

    group('swapLeftRight (mirrored-source correction)', () {
      test('swaps left/right landmarks but keeps their coordinates', () {
        const d = TrackingData(
          boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
          leftEye: Offset(0.6, 0.5),
          rightEye: Offset(0.4, 0.4),
          confidence: 0.9,
          leftIris: Offset(0.61, 0.5),
          rightIris: Offset(0.41, 0.4),
          leftEar: Offset(0.8, 0.5),
          rightEar: Offset(0.2, 0.4),
        );
        final s = d.swapLeftRight();
        expect(s.leftEye, d.rightEye);
        expect(s.rightEye, d.leftEye);
        expect(s.leftIris, d.rightIris);
        expect(s.rightIris, d.leftIris);
        expect(s.leftEar, d.rightEar);
        expect(s.rightEar, d.leftEar);
      });

      test('leaves the eye midpoint and distance untouched', () {
        final d = _data(
          leftEye: const Offset(0.6, 0.5),
          rightEye: const Offset(0.4, 0.4),
        );
        final s = d.swapLeftRight();
        expect(s.eyeCenter, d.eyeCenter);
        expect(s.eyeDistance, closeTo(d.eyeDistance, 1e-12));
      });

      test('reverses the eye vector — a 180° roll change (the bug fix)', () {
        // A mirrored selfie reports its eye vector reversed, so eyewear
        // renders 180°/upside-down; relabeling reverses it back. This is the
        // same correction the live iOS front camera applies.
        final d = _data(
          rightEye: const Offset(0.4, 0.4),
          leftEye: const Offset(0.6, 0.5),
        );
        expect(d.rotation, closeTo(26.565051177077994, 1e-9));
        expect(d.swapLeftRight().rotation, closeTo(-153.43494882292202, 1e-9));
      });

      test('is its own inverse', () {
        final d = _data(
          leftEye: const Offset(0.6, 0.5),
          rightEye: const Offset(0.4, 0.4),
        );
        expect(d.swapLeftRight().swapLeftRight(), equals(d));
      });
    });
  });

  group('OverlayConstraints.isSatisfiedBy', () {
    const viewSize = Size(400, 800);
    // faceWidth 0.4 normalized -> 160 logical px at width 400.

    test('empty constraints always pass', () {
      expect(
        const OverlayConstraints().isSatisfiedBy(_data(), viewSize: viewSize),
        isTrue,
      );
    });

    test('minFaceSize compares against rendered pixel width', () {
      expect(
        const OverlayConstraints(minFaceSize: 150)
            .isSatisfiedBy(_data(), viewSize: viewSize),
        isTrue,
      );
      expect(
        const OverlayConstraints(minFaceSize: 200)
            .isSatisfiedBy(_data(), viewSize: viewSize),
        isFalse,
      );
    });

    test('maxFaceSize hides oversized faces', () {
      expect(
        const OverlayConstraints(maxFaceSize: 150)
            .isSatisfiedBy(_data(), viewSize: viewSize),
        isFalse,
      );
    });

    test('maxHeadTilt compares absolute degrees', () {
      final tilted = _data(
        rightEye: const Offset(0.4, 0.35),
        leftEye: const Offset(0.6, 0.45),
      ); // ~26.57 degrees
      expect(
        const OverlayConstraints(maxHeadTilt: 40)
            .isSatisfiedBy(tilted, viewSize: viewSize),
        isTrue,
      );
      expect(
        const OverlayConstraints(maxHeadTilt: 20)
            .isSatisfiedBy(tilted, viewSize: viewSize),
        isFalse,
      );
    });

    test('minConfidence gates low-confidence detections', () {
      expect(
        const OverlayConstraints(minConfidence: 0.95)
            .isSatisfiedBy(_data(confidence: 0.9), viewSize: viewSize),
        isFalse,
      );
    });

    test('requireIrisDetection needs both irises', () {
      const c = OverlayConstraints(requireIrisDetection: true);
      expect(c.isSatisfiedBy(_data(), viewSize: viewSize), isFalse);
      expect(
        c.isSatisfiedBy(
          _data(
            leftIris: const Offset(0.6, 0.4),
            rightIris: const Offset(0.4, 0.4),
          ),
          viewSize: viewSize,
        ),
        isTrue,
      );
    });
  });

  group('FaceLossBehavior', () {
    test('const variants are canonical', () {
      expect(
        identical(const FaceLossBehavior.hide(), const FaceLossBehavior.hide()),
        isTrue,
      );
    });

    test('fade carries its duration', () {
      const fade = FaceLossBehavior.fade(duration: Duration(seconds: 1));
      expect(
          (fade as FadeFaceLossBehavior).duration, const Duration(seconds: 1));
    });

    test('switches are exhaustive over the sealed hierarchy', () {
      String describe(FaceLossBehavior b) => switch (b) {
            HideFaceLossBehavior() => 'hide',
            FreezeFaceLossBehavior() => 'freeze',
            FadeFaceLossBehavior() => 'fade',
            CustomFaceLossBehavior() => 'custom',
          };
      expect(describe(const FaceLossBehavior.freeze()), 'freeze');
      expect(describe(const FaceLossBehavior.custom()), 'custom');
    });
  });

  group('DebugOptions', () {
    test('defaults are all off', () {
      const d = DebugOptions();
      expect(d.showFPS, isFalse);
      expect(d.showLandmarks, isFalse);
    });

    test('all() turns everything on', () {
      const d = DebugOptions.all();
      expect(d.showFPS, isTrue);
      expect(d.showFaceBox, isTrue);
      expect(d.showLandmarks, isTrue);
      expect(d.showEyeCenters, isTrue);
      expect(d.showAnchors, isTrue);
      expect(d.showRotation, isTrue);
      expect(d.showScale, isTrue);
      expect(d.showTrackingConfidence, isTrue);
    });
  });
}
