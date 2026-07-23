import 'package:flutter/painting.dart';

import '../renderer/eye_anchored_image_painter.dart';
import 'face_overlay.dart';

/// The iris's diameter as a fraction of eye distance. An average human iris
/// is ~11–12mm across and average eye-to-eye (pupil center) distance is
/// ~63mm, so iris diameter ≈ 0.18–0.19× eye distance; 0.19 is used as the
/// automatic default.
const _defaultIrisSizeRatio = 0.19;

/// Renders colored/textured contact lenses on the tracked irises.
///
/// Iris landmarks are backend-dependent (MediaPipe has them, ML Kit does
/// not). When they're unavailable, the overlay automatically falls back to
/// anchoring on the eye centers — pass
/// `visibleWhen: OverlayConstraints(requireIrisDetection: true)` instead if
/// you'd rather hide than approximate.
class ContactLensOverlay extends FaceOverlay {
  /// Creates a contact-lens overlay. Provide at least one texture; an eye
  /// without a texture is left untouched.
  const ContactLensOverlay({
    this.leftTexture,
    this.rightTexture,
    this.irisScale = 1.0,
    this.opacity = 1.0,
    super.visibleWhen,
  });

  /// Texture for the subject's left eye. Circular artwork with transparent
  /// corners expected.
  final ImageProvider? leftTexture;

  /// Texture for the subject's right eye.
  final ImageProvider? rightTexture;

  /// Multiplier on the automatic iris-diameter-based size.
  final double irisScale;

  /// Overlay opacity `0.0 – 1.0`. Lenses usually look natural well below
  /// full opacity.
  final double opacity;

  @override
  void paint(FaceOverlayPaintContext context) {
    final tracking = context.tracking;
    if (leftTexture != null) {
      paintEyeAnchoredPoint(
        context,
        imageProvider: leftTexture!,
        anchorNormalized: tracking.leftIris ?? tracking.leftEye,
        sizeRatio: _defaultIrisSizeRatio,
        scaleMultiplier: irisScale,
        opacity: opacity,
      );
    }
    if (rightTexture != null) {
      paintEyeAnchoredPoint(
        context,
        imageProvider: rightTexture!,
        anchorNormalized: tracking.rightIris ?? tracking.rightEye,
        sizeRatio: _defaultIrisSizeRatio,
        scaleMultiplier: irisScale,
        opacity: opacity,
      );
    }
  }
}
