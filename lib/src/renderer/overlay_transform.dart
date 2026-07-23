// INTERNAL — not exported. Pure geometry: where and how big an
// eye-anchored overlay (glasses, sunglasses, contact lenses) should be
// drawn, given a tracked face and the view it's painted into. Kept free
// of dart:ui's Canvas so it's unit-testable without a rendering surface.

import 'dart:math' as math;
import 'dart:ui';

import '../models/tracking_data.dart';

/// Pixel-space eye geometry shared by every eye-anchored placement:
/// distance between the eyes and head-roll angle, both measured *after*
/// converting to local pixels.
///
/// Deliberately not [TrackingData.eyeDistance]/`rotationRadians` — those
/// are computed over independently width/height-normalized coordinates,
/// only meaningful as relative "closer/farther" or "tilted which way"
/// measures (see their own doc comments). Pixel sizing/rotation needs eye
/// positions converted to local pixels *first*, then measured — otherwise
/// a non-square view or a tilted head mixes two different units under one
/// square root/atan2 and the answer comes out wrong.
class _EyeGeometry {
  const _EyeGeometry({
    required this.leftEyePx,
    required this.rightEyePx,
    required this.distancePx,
    required this.rotation,
  });

  factory _EyeGeometry.of(TrackingData tracking, Size viewSize) {
    final leftEyePx = Offset(
      tracking.leftEye.dx * viewSize.width,
      tracking.leftEye.dy * viewSize.height,
    );
    final rightEyePx = Offset(
      tracking.rightEye.dx * viewSize.width,
      tracking.rightEye.dy * viewSize.height,
    );
    return _EyeGeometry(
      leftEyePx: leftEyePx,
      rightEyePx: rightEyePx,
      distancePx: (rightEyePx - leftEyePx).distance,
      // Same convention as TrackingData.rotationRadians (vector from
      // right eye to left eye), just measured in pixel space.
      rotation: math.atan2(
        leftEyePx.dy - rightEyePx.dy,
        leftEyePx.dx - rightEyePx.dx,
      ),
    );
  }

  final Offset leftEyePx;
  final Offset rightEyePx;
  final double distancePx;
  final double rotation;
}

/// Placement for one frame of an eye-anchored overlay.
class OverlayPlacement {
  /// Creates a placement.
  const OverlayPlacement({
    required this.center,
    required this.width,
    required this.rotation,
  });

  /// Where the overlay's own center should land, in the view's local
  /// pixels.
  final Offset center;

  /// The overlay's rendered width in local pixels, preserving the source
  /// image's aspect ratio (see [OverlayPlacement.forImage]).
  final double width;

  /// Rotation to apply around [center], in radians, matching
  /// `Canvas.rotate`'s convention (positive = clockwise).
  final double rotation;

  /// Computes placement for an eye-anchored overlay image centered on the
  /// eye *midpoint* — glasses, sunglasses.
  ///
  /// Sizing: the rendered width is a multiple of the tracked eye distance
  /// *in local pixels* — [eyeDistanceMultiplier] is how many eye-distances
  /// wide the source image's *design* width represents (a typical frames
  /// photo shot straight-on has temple-to-temple width close to
  /// `eyeDistance * 2.2`–`2.6`; `2.3` is a reasonable middle default).
  /// [scaleMultiplier] (from `GlassesOverlay.scaleMultiplier`) adjusts
  /// that on top, per-overlay.
  ///
  /// Anchor: centered on [TrackingData.eyeCenter], then nudged by
  /// [offsetPixels] (already in local pixels — the caller converts
  /// `GlassesOverlay.offset` before calling this).
  ///
  /// Rotation: pixel-space head roll (see [_EyeGeometry]) plus
  /// [rotationOffsetRadians].
  static OverlayPlacement forImage({
    required TrackingData tracking,
    required Size viewSize,
    double eyeDistanceMultiplier = 2.3,
    double scaleMultiplier = 1.0,
    Offset offsetPixels = Offset.zero,
    double rotationOffsetRadians = 0.0,
  }) {
    final geometry = _EyeGeometry.of(tracking, viewSize);
    final width = geometry.distancePx * eyeDistanceMultiplier * scaleMultiplier;
    final center = Offset(
      (geometry.leftEyePx.dx + geometry.rightEyePx.dx) / 2,
      (geometry.leftEyePx.dy + geometry.rightEyePx.dy) / 2,
    ).translate(offsetPixels.dx, offsetPixels.dy);
    return OverlayPlacement(
      center: center,
      width: width,
      rotation: geometry.rotation + rotationOffsetRadians,
    );
  }

  /// Computes placement for an overlay centered on a single normalized
  /// point — [ContactLensOverlay]'s per-eye lens (iris center, or the eye
  /// center itself when iris landmarks aren't available).
  ///
  /// Sizing still comes from the *pair* of eyes ([sizeRatio] eye-distances
  /// wide, times [scaleMultiplier]) even though the anchor is a single
  /// point — a lens's size should track how close the whole face is, not
  /// just one eye's landmark noise.
  static OverlayPlacement forPoint({
    required TrackingData tracking,
    required Size viewSize,
    required Offset anchorNormalized,
    double sizeRatio = 1.0,
    double scaleMultiplier = 1.0,
    double rotationOffsetRadians = 0.0,
  }) {
    final geometry = _EyeGeometry.of(tracking, viewSize);
    final width = geometry.distancePx * sizeRatio * scaleMultiplier;
    final center = Offset(
      anchorNormalized.dx * viewSize.width,
      anchorNormalized.dy * viewSize.height,
    );
    return OverlayPlacement(
      center: center,
      width: width,
      rotation: geometry.rotation + rotationOffsetRadians,
    );
  }

  /// [width] scaled by [imageAspectRatio] (image width / image height).
  double heightFor(double imageAspectRatio) =>
      imageAspectRatio <= 0 ? width : width / imageAspectRatio;
}
