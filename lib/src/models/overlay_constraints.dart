import 'dart:ui';

import 'tracking_data.dart';

/// Built-in visibility rules for an overlay, so apps don't hand-write
/// "hide the glasses when the face is too small / too tilted" logic.
///
/// Attach via `FaceOverlay.visibleWhen`. The renderer evaluates
/// [isSatisfiedBy] each frame and skips painting the overlay when any rule
/// fails.
class OverlayConstraints {
  /// Creates a set of visibility rules. Omitted rules don't constrain.
  const OverlayConstraints({
    this.minFaceSize,
    this.maxFaceSize,
    this.maxHeadTilt,
    this.minConfidence,
    this.requireBothEyes = false,
    this.requireIrisDetection = false,
  });

  /// Minimum face bounding-box width in **logical pixels of the rendered
  /// view** (the `viewSize` passed to [isSatisfiedBy]). The overlay hides
  /// when the face appears smaller than this.
  final double? minFaceSize;

  /// Maximum face bounding-box width in logical pixels of the rendered
  /// view. The overlay hides when the face appears larger than this.
  final double? maxFaceSize;

  /// Maximum absolute head roll in **degrees** before the overlay hides.
  final double? maxHeadTilt;

  /// Minimum detection confidence (`0.0 – 1.0`) before the overlay hides.
  final double? minConfidence;

  /// Require both eye landmarks. Note every [TrackingData] already carries
  /// both eyes; this exists so future backends that can report a single
  /// visible eye have a rule to honor. Currently always satisfiable.
  final bool requireBothEyes;

  /// Require iris landmarks ([TrackingData.leftIris] and
  /// [TrackingData.rightIris]) — hides the overlay on backends without
  /// iris support (e.g. ML Kit) instead of rendering a misplaced texture.
  final bool requireIrisDetection;

  /// Whether [data], rendered into a box of [viewSize] logical pixels,
  /// satisfies every rule in this set.
  bool isSatisfiedBy(TrackingData data, {required Size viewSize}) {
    final faceWidthPx = data.faceWidth * viewSize.width;
    if (minFaceSize != null && faceWidthPx < minFaceSize!) return false;
    if (maxFaceSize != null && faceWidthPx > maxFaceSize!) return false;
    if (maxHeadTilt != null && data.rotation.abs() > maxHeadTilt!) {
      return false;
    }
    if (minConfidence != null && data.confidence < minConfidence!) {
      return false;
    }
    if (requireIrisDetection &&
        (data.leftIris == null || data.rightIris == null)) {
      return false;
    }
    return true;
  }
}
