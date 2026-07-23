import 'dart:math' as math;
import 'dart:ui';

/// One measurement of a tracked face.
///
/// A [TrackingData] exists only while a face is detected — face loss is
/// signaled separately (`onFaceLost` / `TrackingState.lost`), so every
/// instance you receive describes a real detection.
///
/// ## Coordinate space
///
/// All positions and sizes are **normalized to the analyzed frame**:
/// `(0, 0)` is the frame's top-left corner, `(1, 1)` its bottom-right,
/// with y pointing down (the same orientation as Flutter's [Offset]).
/// This makes values independent of camera resolution and widget size;
/// multiply by a render box's dimensions to get local pixels.
///
/// Coordinates are in the *unmirrored* frame. The rendering layer applies
/// mirroring for selfie preview; consumers of raw data get one consistent
/// space regardless of the `mirror` setting.
///
/// "Left" and "right" are the **subject's own** left and right (so the
/// subject's left eye appears on the right side of an unmirrored selfie) —
/// the convention shared by ML Kit and MediaPipe.
class TrackingData {
  /// Creates a face measurement.
  ///
  /// [boundingBox], [leftEye], [rightEye], and [confidence] are the minimal
  /// data every backend can produce. The remaining landmarks are optional:
  /// backends supply what they support and leave the rest null.
  const TrackingData({
    required this.boundingBox,
    required this.leftEye,
    required this.rightEye,
    required this.confidence,
    this.leftIris,
    this.rightIris,
    this.nose,
    this.chin,
    this.forehead,
    this.leftEar,
    this.rightEar,
    this.fps,
    this.timestamp,
  });

  /// The face's bounding box, normalized (see class docs).
  final Rect boundingBox;

  /// Center of the subject's left eye, normalized.
  final Offset leftEye;

  /// Center of the subject's right eye, normalized.
  final Offset rightEye;

  /// Detection confidence in `0.0 – 1.0`. Backends that don't score
  /// detections report `1.0`.
  final double confidence;

  /// Center of the subject's left iris, normalized. Null when the backend
  /// has no iris landmarks (e.g. ML Kit).
  final Offset? leftIris;

  /// Center of the subject's right iris, normalized. Null when the backend
  /// has no iris landmarks.
  final Offset? rightIris;

  /// Tip of the nose, normalized. Null if unsupported by the backend.
  final Offset? nose;

  /// Bottom of the chin, normalized. Null if unsupported by the backend.
  final Offset? chin;

  /// Center of the forehead, normalized. Null if unsupported by the backend.
  final Offset? forehead;

  /// The subject's left ear, normalized. Null if unsupported by the backend.
  final Offset? leftEar;

  /// The subject's right ear, normalized. Null if unsupported by the backend.
  final Offset? rightEar;

  /// Detection throughput in frames per second, if the backend measures it.
  final double? fps;

  /// When this measurement was produced, if the backend timestamps frames.
  final DateTime? timestamp;

  /// Center of the bounding box, normalized.
  Offset get faceCenter => boundingBox.center;

  /// Bounding-box width as a fraction of frame width.
  double get faceWidth => boundingBox.width;

  /// Bounding-box height as a fraction of frame height.
  double get faceHeight => boundingBox.height;

  /// Midpoint between the two eyes, normalized. The natural anchor for
  /// eyewear overlays.
  Offset get eyeCenter => Offset(
        (leftEye.dx + rightEye.dx) / 2,
        (leftEye.dy + rightEye.dy) / 2,
      );

  /// Distance between the eye centers in normalized units. The engine's
  /// scale reference: overlay sizing is proportional to this.
  double get eyeDistance => (rightEye - leftEye).distance;

  /// How far [faceCenter] sits from the frame center, normalized. Zero
  /// means the face is centered in the frame.
  Offset get translation => faceCenter - const Offset(0.5, 0.5);

  /// Head roll derived from the eye line, in **degrees**. `0` is level.
  /// Positive when the subject's left eye sits lower than their right —
  /// a clockwise rotation on an unmirrored, y-down frame, matching
  /// `Transform.rotate`'s direction.
  double get rotation => rotationRadians * 180 / math.pi;

  /// [rotation] in radians, matching `Transform.rotate`'s convention.
  ///
  /// Measured along the vector from [rightEye] to [leftEye], which points
  /// in +x for a level face (the subject's left eye appears on the frame's
  /// right in an unmirrored image), so a level face reads `0`.
  double get rotationRadians =>
      math.atan2(leftEye.dy - rightEye.dy, leftEye.dx - rightEye.dx);

  /// The engine's dimensionless size measure for this face — currently
  /// defined as [eyeDistance]. Use for relative comparisons ("face got
  /// closer"), not absolute physical size.
  double get scale => eyeDistance;

  @override
  bool operator ==(Object other) {
    return other is TrackingData &&
        other.boundingBox == boundingBox &&
        other.leftEye == leftEye &&
        other.rightEye == rightEye &&
        other.confidence == confidence &&
        other.leftIris == leftIris &&
        other.rightIris == rightIris &&
        other.nose == nose &&
        other.chin == chin &&
        other.forehead == forehead &&
        other.leftEar == leftEar &&
        other.rightEar == rightEar &&
        other.fps == fps &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
        boundingBox,
        leftEye,
        rightEye,
        confidence,
        leftIris,
        rightIris,
        nose,
        chin,
        forehead,
        leftEar,
        rightEar,
        fps,
        timestamp,
      );

  @override
  String toString() =>
      'TrackingData(box: $boundingBox, eyes: $leftEye/$rightEye, '
      'confidence: ${confidence.toStringAsFixed(2)})';
}
