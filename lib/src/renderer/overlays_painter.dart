// INTERNAL — not exported. The shared CustomPainters that composite
// FaceOverlays (and the debug visualizations) over a tracked face. Used by
// both the live VirtualTryOn widget and the still-image VirtualTryOnImage
// widget so there is exactly one overlay paint pipeline.

import 'package:flutter/widgets.dart';

import '../models/debug_options.dart';
import '../models/tracking_data.dart';
import '../overlays/face_overlay.dart';
import 'debug_overlay_painter.dart';
import 'overlay_image_resolver.dart';

/// Paints every [FaceOverlay] against one [TrackingData] measurement,
/// skipping any whose `visibleWhen` constraints aren't satisfied.
class OverlaysPainter extends CustomPainter {
  /// Creates the overlays painter.
  OverlaysPainter({
    required this.overlays,
    required this.data,
    required this.opacity,
    required this.mirrored,
    required this.images,
    required this.imageConfiguration,
  });

  /// The overlays to paint, in order (first is drawn first / bottommost).
  final List<FaceOverlay> overlays;

  /// The measurement to render against.
  final TrackingData data;

  /// Global opacity multiplied into each overlay's own (face-loss fade).
  final double opacity;

  /// Whether the surface is mirrored (selfie mode).
  final bool mirrored;

  /// Resolves/caches overlay artwork images.
  final OverlayImageResolver images;

  /// Configuration passed to [images]`.resolve()`.
  final ImageConfiguration imageConfiguration;

  @override
  void paint(Canvas canvas, Size size) {
    final context = FaceOverlayPaintContext(
      canvas: canvas,
      size: size,
      tracking: data,
      opacity: opacity,
      mirrored: mirrored,
      images: images,
      imageConfiguration: imageConfiguration,
    );
    for (final overlay in overlays) {
      final constraints = overlay.visibleWhen;
      if (constraints != null &&
          !constraints.isSatisfiedBy(data, viewSize: size)) {
        continue;
      }
      overlay.paint(context);
    }
  }

  @override
  bool shouldRepaint(OverlaysPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.opacity != opacity ||
      oldDelegate.mirrored != mirrored ||
      oldDelegate.overlays != overlays ||
      oldDelegate.images != images;
}

/// Paints the [DebugOptions] visualizations above the overlays.
class DebugPainter extends CustomPainter {
  /// Creates the debug painter. [tracking] is null when no face is tracked
  /// (the panel still draws with placeholder values).
  DebugPainter({required this.options, required this.tracking});

  /// Which visualizations to draw.
  final DebugOptions options;

  /// The current measurement, or null when no face is tracked.
  final TrackingData? tracking;

  @override
  void paint(Canvas canvas, Size size) =>
      paintDebugOverlay(canvas, size, options: options, tracking: tracking);

  @override
  bool shouldRepaint(DebugPainter oldDelegate) =>
      oldDelegate.options != options || oldDelegate.tracking != tracking;
}
