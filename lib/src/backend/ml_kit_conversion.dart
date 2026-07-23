// INTERNAL — not exported. Pure conversion from ML Kit's `Face` type to the
// public `TrackingData`. Deliberately free of camera/plugin dependencies so
// it's unit-testable with hand-built `Face` fixtures (see
// doc/TESTING.md: "Unit tests should never depend on a real camera").

import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/tracking_data.dart';
import 'ml_kit_rotation.dart';

/// Converts one detected [face] into [TrackingData], normalizing its
/// geometry against [imageSize].
///
/// File-path detection (photo mode) reports landmarks already upright, so
/// call this with just [face] and [imageSize]. Live-stream detection
/// reports landmarks in the *raw sensor buffer's* coordinate space; pass
/// [rawSize] and [rotation] (from the same [InputImage] that was detected)
/// to rotate everything into the same upright space photo mode uses first —
/// otherwise the two paths would disagree about where a face is.
///
/// Returns null when the face lacks eye landmarks — [TrackingData] requires
/// both eyes, and ML Kit's landmarks are opportunistic (a profile view, for
/// instance, may miss one). Requires [FaceDetectorOptions.enableLandmarks].
///
/// ML Kit has no confidence score for detection itself (only per-attribute
/// probabilities like `smilingProbability`, which this package doesn't
/// request), so [TrackingData.confidence] is always `1.0` — matching the
/// class's documented behavior for backends that don't score detections.
/// ML Kit has no iris, chin, or forehead landmarks; those fields stay null.
///
/// [fps] and [timestamp] are passed straight through to the result — this
/// function has no notion of frame rate itself (a single detection isn't
/// enough to compute one); the caller measures across calls.
TrackingData? mlKitFaceToTrackingData(
  Face face,
  Size imageSize, {
  Size? rawSize,
  InputImageRotation? rotation,
  bool swapLeftRight = false,
  double? fps,
  DateTime? timestamp,
}) {
  // A mirrored source buffer (the iOS front camera) reports ML Kit's
  // left/right landmarks on the opposite sides from TrackingData's
  // *unmirrored*, subject-relative convention (doc/DECISIONS.md #015):
  // the subject's left eye ends up at a smaller x than their right, the
  // reverse of the convention. [swapLeftRight] corrects the handedness by
  // swapping which ML Kit landmark feeds `leftEye`/`rightEye` (and the
  // ears) — a *relabeling*, not a coordinate change, so the eye midpoint
  // (and thus overlay position) is untouched while the eye vector, and the
  // overlay rotation derived from it, comes out right. Mirroring the
  // coordinates instead would (correctly) fix rotation but shift the
  // overlay to the mirrored x-position, since the renderer keeps preview
  // and overlay in the same raw-buffer space and flips both together.
  final leftEyeType =
      swapLeftRight ? FaceLandmarkType.rightEye : FaceLandmarkType.leftEye;
  final rightEyeType =
      swapLeftRight ? FaceLandmarkType.leftEye : FaceLandmarkType.rightEye;
  final leftEarType =
      swapLeftRight ? FaceLandmarkType.rightEar : FaceLandmarkType.leftEar;
  final rightEarType =
      swapLeftRight ? FaceLandmarkType.leftEar : FaceLandmarkType.rightEar;

  final leftEye = face.landmarks[leftEyeType]?.position;
  final rightEye = face.landmarks[rightEyeType]?.position;
  if (leftEye == null || rightEye == null) return null;
  if (imageSize.width <= 0 || imageSize.height <= 0) return null;

  final needsRotation = rawSize != null &&
      rotation != null &&
      rotation != InputImageRotation.rotation0deg;

  Offset upright(double x, double y) {
    final p = Offset(x, y);
    return needsRotation ? mlKitUprightPoint(p, rawSize, rotation) : p;
  }

  Offset normalize(Offset p) =>
      Offset(p.dx / imageSize.width, p.dy / imageSize.height);

  Offset point(num x, num y) => normalize(upright(x.toDouble(), y.toDouble()));

  Offset? landmark(FaceLandmarkType type) {
    final p = face.landmarks[type]?.position;
    return p == null ? null : point(p.x, p.y);
  }

  final box = face.boundingBox;
  // Rect.fromPoints reorders edges correctly even if a 90/270 rotation
  // swapped which corner ends up top-left vs bottom-right.
  final normalizedBox = Rect.fromPoints(
    normalize(upright(box.left, box.top)),
    normalize(upright(box.right, box.bottom)),
  );

  return TrackingData(
    boundingBox: normalizedBox,
    leftEye: point(leftEye.x, leftEye.y),
    rightEye: point(rightEye.x, rightEye.y),
    confidence: 1.0,
    nose: landmark(FaceLandmarkType.noseBase),
    leftEar: landmark(leftEarType),
    rightEar: landmark(rightEarType),
    fps: fps,
    timestamp: timestamp,
  );
}

/// Picks the most prominent face — largest bounding-box area, i.e. closest
/// to the camera — from a detection pass. ML Kit doesn't score prominence
/// itself, and the package supports one face per doc/DECISIONS.md #007.
Face? pickPrimaryFace(List<Face> faces) {
  if (faces.isEmpty) return null;
  return faces.reduce((a, b) {
    final areaA = a.boundingBox.width * a.boundingBox.height;
    final areaB = b.boundingBox.width * b.boundingBox.height;
    return areaB > areaA ? b : a;
  });
}
