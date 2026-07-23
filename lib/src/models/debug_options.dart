/// Which diagnostic visualizations the built-in debug overlay draws.
///
/// Only consulted when `VirtualTryOn.debugMode` is true. All flags default
/// to off; [DebugOptions.all] turns everything on.
class DebugOptions {
  /// Creates debug options with every visualization off by default.
  const DebugOptions({
    this.showFPS = false,
    this.showFaceBox = false,
    this.showLandmarks = false,
    this.showEyeCenters = false,
    this.showAnchors = false,
    this.showRotation = false,
    this.showScale = false,
    this.showTrackingConfidence = false,
  });

  /// Enables every debug visualization.
  const DebugOptions.all()
      : showFPS = true,
        showFaceBox = true,
        showLandmarks = true,
        showEyeCenters = true,
        showAnchors = true,
        showRotation = true,
        showScale = true,
        showTrackingConfidence = true;

  /// Draw the detection frame rate.
  final bool showFPS;

  /// Draw the face bounding box.
  final bool showFaceBox;

  /// Draw every landmark the backend reported.
  final bool showLandmarks;

  /// Mark the detected eye centers.
  final bool showEyeCenters;

  /// Mark the anchor points overlays attach to (e.g. the eye midpoint).
  final bool showAnchors;

  /// Print the current head-roll angle.
  final bool showRotation;

  /// Print the current scale measure (eye distance).
  final bool showScale;

  /// Print the current detection confidence.
  final bool showTrackingConfidence;
}
