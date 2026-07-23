// INTERNAL — not exported. Backs `VirtualTryOn.smoothTracking`.

import 'dart:ui';

import '../models/tracking_data.dart';

/// Exponential moving average smoothing over consecutive [TrackingData]
/// measurements, to suppress frame-to-frame jitter (doc/ARCHITECTURE.md's
/// "smoothing engine").
///
/// Every landmark and the bounding box are blended toward the new sample by
/// [alpha] each call: `alpha = 1.0` is no smoothing (always the latest
/// sample); smaller values lag more but move less erratically. `0.35` is
/// chosen as a middle ground — enough lag to flatten single-frame detector
/// noise, not so much that fast head movement visibly trails. `fps` and
/// `timestamp` pass through unsmoothed — they're diagnostic, not spatial.
///
/// Deliberately stateful and NOT a pure function: each call depends on the
/// previous one. [reset] must be called across a tracking gap (face lost
/// and reacquired) — otherwise the first post-reacquisition sample would
/// blend toward a stale, no-longer-relevant position.
class TrackingSmoother {
  /// Creates a smoother. [alpha] is exposed for tests; production code
  /// uses the default.
  TrackingSmoother({this.alpha = 0.35})
      : assert(alpha > 0 && alpha <= 1, 'alpha must be in (0, 1]');

  /// Weight given to each new sample; see class doc.
  final double alpha;

  TrackingData? _previous;

  /// Blends [current] with the previous sample (if any) and returns the
  /// result. The very first call after construction or [reset] returns
  /// [current] unchanged — there's nothing to blend with yet.
  TrackingData smooth(TrackingData current) {
    final previous = _previous;
    // alpha == 1.0 is an explicit "no smoothing" escape hatch — skip the
    // blend (and its allocation) entirely rather than compute a lerp that
    // always lands exactly on `current`.
    final result = (previous == null || alpha == 1.0)
        ? current
        : _blend(previous, current);
    _previous = result;
    return result;
  }

  /// Clears smoothing history. Call after a tracking gap so the next
  /// [smooth] call snaps directly to the reacquired position instead of
  /// blending from a stale one.
  void reset() => _previous = null;

  TrackingData _blend(TrackingData previous, TrackingData current) {
    Offset lerpRequired(Offset a, Offset b) => Offset.lerp(a, b, alpha)!;
    Offset? lerpOptional(Offset? a, Offset? b) {
      // A landmark that disappears or appears between frames can't be
      // blended against nothing — snap to whatever's available instead of
      // guessing.
      if (a == null || b == null) return b;
      return Offset.lerp(a, b, alpha);
    }

    return TrackingData(
      boundingBox: Rect.lerp(previous.boundingBox, current.boundingBox, alpha)!,
      leftEye: lerpRequired(previous.leftEye, current.leftEye),
      rightEye: lerpRequired(previous.rightEye, current.rightEye),
      confidence: lerpDouble(previous.confidence, current.confidence, alpha)!,
      leftIris: lerpOptional(previous.leftIris, current.leftIris),
      rightIris: lerpOptional(previous.rightIris, current.rightIris),
      nose: lerpOptional(previous.nose, current.nose),
      chin: lerpOptional(previous.chin, current.chin),
      forehead: lerpOptional(previous.forehead, current.forehead),
      leftEar: lerpOptional(previous.leftEar, current.leftEar),
      rightEar: lerpOptional(previous.rightEar, current.rightEar),
      fps: current.fps,
      timestamp: current.timestamp,
    );
  }
}
