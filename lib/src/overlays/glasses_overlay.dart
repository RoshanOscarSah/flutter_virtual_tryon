import 'package:flutter/painting.dart';

import '../renderer/eye_anchored_image_painter.dart';
import 'face_overlay.dart';

/// Renders a glasses image anchored to the tracked eyes.
///
/// The image is any [ImageProvider] (asset, network, file, memory) — a
/// transparent PNG of frames viewed straight-on works best. The engine
/// positions it at the eye midpoint, scales it proportionally to the eye
/// distance, and rotates it with head roll; [scaleMultiplier], [offset],
/// and [rotationOffset] fine-tune that automatic placement (use the
/// calibration tools to find values — see doc/PRODUCT_REQUIREMENTS.md).
class GlassesOverlay extends FaceOverlay {
  /// Creates a glasses overlay for [image].
  const GlassesOverlay({
    required this.image,
    this.scaleMultiplier = 1.0,
    this.offset = Offset.zero,
    this.rotationOffset = 0.0,
    this.opacity = 1.0,
    super.visibleWhen,
  });

  /// The glasses artwork. Transparent background expected.
  final ImageProvider image;

  /// Multiplier on the automatic eye-distance-based size. `1.0` means the
  /// engine's default sizing; `1.08` renders 8% larger.
  final double scaleMultiplier;

  /// Nudge from the automatic anchor position, in logical pixels at the
  /// rendered size. Positive y moves down.
  final Offset offset;

  /// Additional rotation in **degrees**, on top of tracked head roll.
  final double rotationOffset;

  /// Overlay opacity `0.0 – 1.0`, multiplied with any face-loss fade.
  final double opacity;

  @override
  void paint(FaceOverlayPaintContext context) {
    paintEyeAnchoredImage(
      context,
      imageProvider: image,
      scaleMultiplier: scaleMultiplier,
      offsetPixels: offset,
      rotationOffsetDegrees: rotationOffset,
      opacity: opacity,
    );
  }
}
