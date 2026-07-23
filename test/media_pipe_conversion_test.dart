import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/src/backend/media_pipe_conversion.dart';

/// Builds a synthetic 468 (or 478 with [withIris]) point flat landmark
/// list. Every point defaults to (0.5, 0.5) except the ones this package
/// actually reads, which get distinct, easily-asserted values.
List<double> _landmarks({bool withIris = false}) {
  final count = withIris ? 478 : 468;
  final flat = List<double>.filled(count * 2, 0.5);
  void set(int index, double x, double y) {
    flat[index * 2] = x;
    flat[index * 2 + 1] = y;
  }

  // Eye corners (subject-relative, matching the donor's proven mapping).
  set(362, 0.58, 0.40); // left eye inner
  set(263, 0.62, 0.40); // left eye outer -> left eye midpoint (0.60, 0.40)
  set(33, 0.38, 0.40); // right eye outer
  set(133, 0.42, 0.40); // right eye inner -> right eye midpoint (0.40, 0.40)
  set(1, 0.50, 0.55); // nose tip
  set(152, 0.50, 0.75); // chin
  set(10, 0.50, 0.15); // forehead
  // Bounding box extremes, distinct from the 0.5 filler.
  set(0, 0.20, 0.10); // min x, min y contributor
  set(400, 0.80, 0.90); // max x, max y contributor
  if (withIris) {
    set(468, 0.61, 0.41); // left iris
    set(473, 0.39, 0.41); // right iris
  }
  return flat;
}

void main() {
  group('mediaPipeLandmarksToTrackingData', () {
    test('returns null for too few points', () {
      expect(mediaPipeLandmarksToTrackingData(List.filled(20, 0.0)), isNull);
    });

    test('returns null for an odd-length list', () {
      expect(
        mediaPipeLandmarksToTrackingData(List.filled(937, 0.0)),
        isNull,
      );
    });

    test('computes eye centers from corner midpoints', () {
      final data = mediaPipeLandmarksToTrackingData(_landmarks())!;
      expect(data.leftEye.dx, closeTo(0.60, 1e-9));
      expect(data.leftEye.dy, closeTo(0.40, 1e-9));
      expect(data.rightEye.dx, closeTo(0.40, 1e-9));
      expect(data.rightEye.dy, closeTo(0.40, 1e-9));
    });

    test('computes bounding box as the extremes of all points', () {
      final data = mediaPipeLandmarksToTrackingData(_landmarks())!;
      expect(data.boundingBox.left, closeTo(0.20, 1e-9));
      expect(data.boundingBox.top, closeTo(0.10, 1e-9));
      expect(data.boundingBox.right, closeTo(0.80, 1e-9));
      expect(data.boundingBox.bottom, closeTo(0.90, 1e-9));
    });

    test('nose, chin, forehead are populated from fixed indices', () {
      final data = mediaPipeLandmarksToTrackingData(_landmarks())!;
      expect(data.nose, const Offset(0.50, 0.55));
      expect(data.chin, const Offset(0.50, 0.75));
      expect(data.forehead, const Offset(0.50, 0.15));
    });

    test('iris is null without refinement (468 points)', () {
      final data = mediaPipeLandmarksToTrackingData(_landmarks())!;
      expect(data.leftIris, isNull);
      expect(data.rightIris, isNull);
    });

    test('iris is populated with refinement (478 points)', () {
      final data = mediaPipeLandmarksToTrackingData(
        _landmarks(withIris: true),
      )!;
      expect(data.leftIris, const Offset(0.61, 0.41));
      expect(data.rightIris, const Offset(0.39, 0.41));
    });

    test('confidence is always 1.0 (no face-level score in this result)', () {
      expect(mediaPipeLandmarksToTrackingData(_landmarks())!.confidence, 1.0);
    });

    test(
        'left/right ear are always null (unverified indices, see '
        'doc/DECISIONS.md #022)', () {
      final data = mediaPipeLandmarksToTrackingData(_landmarks())!;
      expect(data.leftEar, isNull);
      expect(data.rightEar, isNull);
    });
  });
}
