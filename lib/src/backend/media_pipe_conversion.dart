// INTERNAL — not exported. Pure conversion from a MediaPipe Face Landmarker
// result (a flat, normalized [x0, y0, x1, y1, ...] point list) to the public
// `TrackingData`. Kept free of dart:js_interop so it's unit-testable on the
// VM test runner with a synthetic landmark list — the JS bridge
// (media_pipe_backend.dart, web-only) does nothing but marshal the raw
// landmark array here.

import 'dart:ui';

import '../models/tracking_data.dart';

// MediaPipe's 468-point face mesh has fixed, well-known indices, reused
// here exactly as proven in production (see doc/HANDOVER.md): 33/133 are
// the subject's right eye's outer/inner corners, 362/263 the left eye's
// inner/outer corners; 1 is the nose tip, 152 the chin, 10 the forehead.
// Builds with iris refinement append 10 more points (478 total): 468 is
// the left iris center, 473 the right — strictly more accurate than the
// eye-corner midpoint when present.
//
// Left/right ear indices are deliberately NOT included: unlike the values
// above, they were not exercised in the donor implementation, and shipping
// an unverified index risks silently mislabeling left vs. right — worse
// than the documented null. See doc/DECISIONS.md #022.
const _rightEyeOuter = 33;
const _rightEyeInner = 133;
const _leftEyeInner = 362;
const _leftEyeOuter = 263;
const _leftIris = 468;
const _rightIris = 473;
const _noseTip = 1;
const _chin = 152;
const _forehead = 10;

/// Minimum landmark count for a valid MediaPipe Face Mesh result (468
/// points; 478 with iris refinement).
const mediaPipeMinLandmarkCount = 468;

/// Converts a flat, normalized landmark list (`[x0, y0, x1, y1, ...]`, as
/// produced by MediaPipe Face Landmarker) into [TrackingData].
///
/// Returns null when [flatLandmarks] doesn't look like a face mesh (wrong
/// length) — never throws on malformed input, matching every other
/// backend's "no valid detection" contract.
///
/// [fps] and [timestamp] are passed straight through to the result — this
/// function has no notion of frame rate itself; the caller measures
/// across calls.
TrackingData? mediaPipeLandmarksToTrackingData(
  List<double> flatLandmarks, {
  double? fps,
  DateTime? timestamp,
}) {
  final count = flatLandmarks.length ~/ 2;
  if (count < mediaPipeMinLandmarkCount || flatLandmarks.length.isOdd) {
    return null;
  }

  Offset at(int index) =>
      Offset(flatLandmarks[index * 2], flatLandmarks[index * 2 + 1]);

  Offset midpoint(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  final hasIris = count > _rightIris;

  final leftEye = midpoint(at(_leftEyeInner), at(_leftEyeOuter));
  final rightEye = midpoint(at(_rightEyeOuter), at(_rightEyeInner));

  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;
  for (var i = 0; i < count; i++) {
    final p = at(i);
    if (p.dx < minX) minX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy > maxY) maxY = p.dy;
  }

  return TrackingData(
    boundingBox: Rect.fromLTRB(minX, minY, maxX, maxY),
    leftEye: leftEye,
    rightEye: rightEye,
    // No face-level confidence in this result shape; see TrackingData's
    // documented default for backends that don't score detections.
    confidence: 1.0,
    leftIris: hasIris ? at(_leftIris) : null,
    rightIris: hasIris ? at(_rightIris) : null,
    nose: at(_noseTip),
    chin: at(_chin),
    forehead: at(_forehead),
    fps: fps,
    timestamp: timestamp,
  );
}
