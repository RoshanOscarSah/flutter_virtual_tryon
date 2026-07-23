import 'dart:math';
import 'dart:ui';

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
