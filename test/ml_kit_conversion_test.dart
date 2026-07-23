import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_virtual_tryon/src/backend/ml_kit_conversion.dart';
import 'package:flutter_virtual_tryon/src/backend/ml_kit_rotation.dart';

Face _face({
  required Rect boundingBox,
  Point<int>? leftEye,
  Point<int>? rightEye,
  Point<int>? noseBase,
  Point<int>? leftEar,
  Point<int>? rightEar,
}) {
  final landmarks = <FaceLandmarkType, FaceLandmark?>{};
  void put(FaceLandmarkType type, Point<int>? p) {
    if (p != null) landmarks[type] = FaceLandmark(type: type, position: p);
  }

  put(FaceLandmarkType.leftEye, leftEye);
  put(FaceLandmarkType.rightEye, rightEye);
  put(FaceLandmarkType.noseBase, noseBase);
  put(FaceLandmarkType.leftEar, leftEar);
  put(FaceLandmarkType.rightEar, rightEar);

  return Face(
    boundingBox: boundingBox,
    landmarks: landmarks,
    contours: const {},
  );
}

void main() {
  group('mlKitUprightPoint / mlKitUprightSize (rotation primitives)', () {
    const rawSize = Size(800, 1000); // w=800, h=1000

    test('rotation0deg is identity', () {
      expect(
        mlKitUprightPoint(
          const Offset(650, 200),
          rawSize,
          InputImageRotation.rotation0deg,
        ),
        const Offset(650, 200),
      );
      expect(
        mlKitUprightSize(rawSize, InputImageRotation.rotation0deg),
        rawSize,
      );
    });

    test('rotation90deg: (h - y, x), and swaps width/height', () {
      expect(
        mlKitUprightPoint(
          const Offset(650, 200),
          rawSize,
          InputImageRotation.rotation90deg,
        ),
        const Offset(800, 650), // (1000 - 200, 650)
      );
      expect(
        mlKitUprightSize(rawSize, InputImageRotation.rotation90deg),
        const Size(1000, 800),
      );
    });

    test('rotation180deg: (w - x, h - y), size unchanged', () {
      expect(
        mlKitUprightPoint(
          const Offset(650, 200),
          rawSize,
          InputImageRotation.rotation180deg,
        ),
        const Offset(150, 800), // (800 - 650, 1000 - 200)
      );
      expect(
        mlKitUprightSize(rawSize, InputImageRotation.rotation180deg),
        rawSize,
      );
    });

    test('rotation270deg: (y, w - x), and swaps width/height', () {
      expect(
        mlKitUprightPoint(
          const Offset(650, 200),
          rawSize,
          InputImageRotation.rotation270deg,
        ),
        const Offset(200, 150), // (200, 800 - 650)
      );
      expect(
        mlKitUprightSize(rawSize, InputImageRotation.rotation270deg),
        const Size(1000, 800),
      );
    });
  });

  group('mlKitFaceToTrackingData — photo mode (no rotation)', () {
    // 1000x800 image; subject's left eye on the right side of the frame
    // (unmirrored selfie convention), matching TrackingData's contract.
    final face = _face(
      boundingBox: const Rect.fromLTWH(200, 150, 400, 500),
      leftEye: const Point(600, 350),
      rightEye: const Point(400, 350),
      noseBase: const Point(500, 450),
      leftEar: const Point(650, 360),
      rightEar: const Point(350, 360),
    );
    const imageSize = Size(1000, 800);

    test('normalizes every point by image dimensions', () {
      final data = mlKitFaceToTrackingData(face, imageSize)!;
      expect(data.leftEye, const Offset(0.6, 0.4375));
      expect(data.rightEye, const Offset(0.4, 0.4375));
      expect(data.nose, const Offset(0.5, 0.5625));
      expect(data.leftEar, const Offset(0.65, 0.45));
      expect(data.rightEar, const Offset(0.35, 0.45));
    });

    test('normalizes the bounding box', () {
      // Rect.fromPoints (used internally) can differ from a hand-typed
      // literal in the last bit, so compare edges with a tolerance rather
      // than asserting exact Rect equality.
      final box = mlKitFaceToTrackingData(face, imageSize)!.boundingBox;
      expect(box.left, closeTo(0.2, 1e-9));
      expect(box.top, closeTo(0.1875, 1e-9));
      expect(box.right, closeTo(0.6, 1e-9));
      expect(box.bottom, closeTo(0.8125, 1e-9));
    });

    test('confidence is always 1.0 (ML Kit has no detection score)', () {
      expect(mlKitFaceToTrackingData(face, imageSize)!.confidence, 1.0);
    });

    test('iris, chin, forehead are always null', () {
      final data = mlKitFaceToTrackingData(face, imageSize)!;
      expect(data.leftIris, isNull);
      expect(data.rightIris, isNull);
      expect(data.chin, isNull);
      expect(data.forehead, isNull);
    });

    test('returns null when an eye landmark is missing', () {
      final oneEyed = _face(
        boundingBox: const Rect.fromLTWH(200, 150, 400, 500),
        leftEye: const Point(600, 350),
      );
      expect(mlKitFaceToTrackingData(oneEyed, imageSize), isNull);
    });

    test('returns null for a zero-size image', () {
      expect(mlKitFaceToTrackingData(face, Size.zero), isNull);
    });

    test('optional landmarks null when not detected', () {
      final minimal = _face(
        boundingBox: const Rect.fromLTWH(200, 150, 400, 500),
        leftEye: const Point(600, 350),
        rightEye: const Point(400, 350),
      );
      final data = mlKitFaceToTrackingData(minimal, imageSize)!;
      expect(data.nose, isNull);
      expect(data.leftEar, isNull);
      expect(data.rightEar, isNull);
    });
  });

  group('mlKitFaceToTrackingData — live stream rotation', () {
    test('rotated eyes/box match mlKitUprightPoint, then normalize', () {
      const rawSize = Size(800, 1000);
      const rotation = InputImageRotation.rotation90deg;
      final face = _face(
        boundingBox: const Rect.fromLTWH(100, 100, 200, 300),
        leftEye: const Point(650, 200),
        rightEye: const Point(600, 350),
      );
      final uprightSize = mlKitUprightSize(rawSize, rotation);
      final data = mlKitFaceToTrackingData(
        face,
        uprightSize,
        rawSize: rawSize,
        rotation: rotation,
      )!;

      Offset expectedNormalized(Offset raw) {
        final upright = mlKitUprightPoint(raw, rawSize, rotation);
        return Offset(
          upright.dx / uprightSize.width,
          upright.dy / uprightSize.height,
        );
      }

      expect(data.leftEye, expectedNormalized(const Offset(650, 200)));
      expect(data.rightEye, expectedNormalized(const Offset(600, 350)));
      // Verified against the hand-computed rotation90deg case above:
      // (650,200) -> (800,650) -> normalized by 1000x800 -> (0.8, 0.8125).
      expect(data.leftEye, const Offset(0.8, 0.8125));
    });

    test('rotation0deg matches omitting rotation entirely', () {
      const imageSize = Size(1000, 800);
      final face = _face(
        boundingBox: const Rect.fromLTWH(200, 150, 400, 500),
        leftEye: const Point(600, 350),
        rightEye: const Point(400, 350),
      );
      final withRotation = mlKitFaceToTrackingData(
        face,
        imageSize,
        rawSize: imageSize,
        rotation: InputImageRotation.rotation0deg,
      );
      final withoutRotation = mlKitFaceToTrackingData(face, imageSize);
      expect(withRotation, withoutRotation);
    });
  });

  group('mlKitRotationForCamera', () {
    // The rotation ML Kit is handed follows Google's own recipe, which is
    // deliberately asymmetric by platform (see the function's own doc): iOS
    // uses the fixed sensorOrientation because the plugin delivers
    // display-oriented frames; Android combines sensorOrientation with the
    // live deviceOrientation because its frames are raw-sensor-oriented.

    test('iOS ignores deviceOrientation and uses sensorOrientation directly',
        () {
      // Same sensorOrientation -> same rotation regardless of how the
      // device is held (the plugin already oriented the buffer).
      for (final orientation in [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        null,
      ]) {
        expect(
          mlKitRotationForCamera(
            platform: TargetPlatform.iOS,
            sensorOrientation: 90,
            lensDirection: CameraLensDirection.front,
            deviceOrientation: orientation,
          ),
          InputImageRotation.rotation90deg,
        );
      }
    });

    test('Android returns null for an unrecognized/null device orientation',
        () {
      expect(
        mlKitRotationForCamera(
          platform: TargetPlatform.android,
          sensorOrientation: 270,
          lensDirection: CameraLensDirection.front,
          deviceOrientation: null,
        ),
        isNull,
      );
    });

    test('Android front camera: (sensorOrientation + deviceOrientation) % 360',
        () {
      expect(
        mlKitRotationForCamera(
          platform: TargetPlatform.android,
          sensorOrientation: 270,
          lensDirection: CameraLensDirection.front,
          deviceOrientation: DeviceOrientation.portraitUp,
        ),
        InputImageRotation.rotation270deg,
      );
      // landscapeLeft contributes 90 degrees: (270 + 90) % 360 = 0.
      expect(
        mlKitRotationForCamera(
          platform: TargetPlatform.android,
          sensorOrientation: 270,
          lensDirection: CameraLensDirection.front,
          deviceOrientation: DeviceOrientation.landscapeLeft,
        ),
        InputImageRotation.rotation0deg,
      );
    });

    test(
        'Android back camera: '
        '(sensorOrientation - deviceOrientation + 360) % 360', () {
      expect(
        mlKitRotationForCamera(
          platform: TargetPlatform.android,
          sensorOrientation: 90,
          lensDirection: CameraLensDirection.back,
          deviceOrientation: DeviceOrientation.portraitUp,
        ),
        InputImageRotation.rotation90deg,
      );
      // landscapeLeft contributes 90 degrees: (90 - 90 + 360) % 360 = 0.
      expect(
        mlKitRotationForCamera(
          platform: TargetPlatform.android,
          sensorOrientation: 90,
          lensDirection: CameraLensDirection.back,
          deviceOrientation: DeviceOrientation.landscapeLeft,
        ),
        InputImageRotation.rotation0deg,
      );
    });
  });

  group('mlKitFaceToTrackingData — iOS coordinate handling (regression)', () {
    // Regression for the real bug behind vertically-stacked landmarks on a
    // live iOS camera. ML Kit on iOS returns detections already in the
    // display-upright orientation (the plugin delivers an oriented buffer,
    // and google_ml_kit's own coordinates_translator.dart normalizes iOS
    // points against the raw image dimensions with no rotation). Running
    // those already-upright points through mlKitUprightPoint — as the code
    // wrongly did on iOS — rotated them another 90°, stacking eyes/nose/
    // chin into a vertical line. The fix: iOS calls this function with just
    // (face, rawSize) — no rawSize+rotation pair — so no rotation is applied.

    test(
        'iOS path (no rotation args) normalizes raw points directly, '
        'leaving a level face level', () {
      // Eyes side by side on a level face, in the already-upright iOS
      // buffer's own pixel space.
      final face = _face(
        boundingBox: const Rect.fromLTWH(200, 150, 400, 300),
        leftEye: const Point(560, 300),
        rightEye: const Point(360, 300),
      );
      const iosBufferSize = Size(800, 600);
      final data = mlKitFaceToTrackingData(face, iosBufferSize)!;

      // Direct normalization, no rotation: x/800, y/600.
      expect(data.leftEye, const Offset(0.7, 0.5));
      expect(data.rightEye, const Offset(0.45, 0.5));
      // The eyes share a y — a level face stays level (the exact symptom
      // that broke: they must NOT end up stacked at one x).
      expect(data.leftEye.dy, data.rightEye.dy);
      expect(data.leftEye.dx, isNot(data.rightEye.dx));
    });

    test(
        'swapLeftRight relabels eyes into the subject-left-on-right '
        'convention WITHOUT moving them — fixing 180°/upside-down overlays '
        'on the iOS front camera while keeping position correct', () {
      // The iOS front-camera buffer is mirrored, so ML Kit reports the
      // subject's left eye at a SMALLER x than their right — the reverse of
      // TrackingData's contract (doc/DECISIONS.md #015). Without the swap
      // the eye vector points the wrong way and eye-anchored overlays
      // rotate 180° (the reported upside-down glasses).
      final mirroredFace = _face(
        boundingBox: const Rect.fromLTWH(200, 150, 400, 300),
        leftEye: const Point(360, 300), // ML Kit's "left" at the SMALLER x
        rightEye: const Point(560, 300),
        leftEar: const Point(300, 310),
        rightEar: const Point(620, 310),
      );
      const iosBufferSize = Size(800, 600);

      final plain = mlKitFaceToTrackingData(mirroredFace, iosBufferSize)!;
      final swapped = mlKitFaceToTrackingData(
        mirroredFace,
        iosBufferSize,
        swapLeftRight: true,
      )!;

      // Coordinates are NOT flipped: the two eye points stay put, they're
      // just relabeled. So the eye MIDPOINT (= overlay anchor) is identical
      // with or without the swap — the overlay doesn't move sideways.
      expect(
        Offset(
          (swapped.leftEye.dx + swapped.rightEye.dx) / 2,
          (swapped.leftEye.dy + swapped.rightEye.dy) / 2,
        ),
        Offset(
          (plain.leftEye.dx + plain.rightEye.dx) / 2,
          (plain.leftEye.dy + plain.rightEye.dy) / 2,
        ),
      );

      // But left/right are now swapped: TrackingData.leftEye takes the
      // LARGER x (ML Kit's rightEye), satisfying the convention, so the
      // rightEye -> leftEye vector points +x (level, upright) not reversed.
      expect(swapped.leftEye, plain.rightEye);
      expect(swapped.rightEye, plain.leftEye);
      expect(swapped.leftEye.dx, greaterThan(swapped.rightEye.dx));
      // Ears swap too, for consistent subject-relative labeling.
      expect(swapped.leftEar, plain.rightEar);
      expect(swapped.rightEar, plain.leftEar);
    });
  });

  group('pickPrimaryFace', () {
    test('returns null for an empty list', () {
      expect(pickPrimaryFace(const []), isNull);
    });

    test('picks the largest bounding box', () {
      final small = _face(boundingBox: const Rect.fromLTWH(0, 0, 100, 100));
      final large = _face(boundingBox: const Rect.fromLTWH(0, 0, 300, 300));
      expect(pickPrimaryFace([small, large]), same(large));
      expect(pickPrimaryFace([large, small]), same(large));
    });
  });
}
