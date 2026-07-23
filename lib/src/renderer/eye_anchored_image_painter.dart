// INTERNAL — not exported. Shared paint logic for eye-anchored image
// overlays (GlassesOverlay, SunglassesOverlay, ContactLensOverlay):
// resolve the image, place it via overlay_transform.dart's pure geometry,
// and blit it with Flutter's own paintImage() helper rather than
// hand-rolling drawImageRect + opacity composition.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show BoxFit, ImageProvider, paintImage;

import '../overlays/face_overlay.dart';
import 'overlay_transform.dart';

/// Paints [imageProvider] anchored to the eye midpoint in [context] —
/// [GlassesOverlay]/[SunglassesOverlay].
///
/// Does nothing (silently) if the image hasn't finished resolving yet —
/// `OverlayImageResolver` schedules a repaint once it has, so the overlay
/// simply appears a frame or two after the underlying image loads, exactly
/// like an [Image] widget would.
void paintEyeAnchoredImage(
  FaceOverlayPaintContext context, {
  required ImageProvider imageProvider,
  required double scaleMultiplier,
  required Offset offsetPixels,
  required double rotationOffsetDegrees,
  required double opacity,
}) {
  final image =
      context.images.resolve(imageProvider, context.imageConfiguration);
  if (image == null) return;

  final placement = OverlayPlacement.forImage(
    tracking: context.tracking,
    viewSize: context.size,
    scaleMultiplier: scaleMultiplier,
    offsetPixels: offsetPixels,
    rotationOffsetRadians: rotationOffsetDegrees * math.pi / 180,
  );
  _paintImageAtPlacement(context,
      image: image, placement: placement, opacity: opacity);
}

/// Paints [imageProvider] anchored to a single normalized point in
/// [context] — [ContactLensOverlay]'s per-eye lens.
///
/// Same "does nothing before the image resolves" contract as
/// [paintEyeAnchoredImage].
void paintEyeAnchoredPoint(
  FaceOverlayPaintContext context, {
  required ImageProvider imageProvider,
  required Offset anchorNormalized,
  required double sizeRatio,
  required double scaleMultiplier,
  required double opacity,
}) {
  final image =
      context.images.resolve(imageProvider, context.imageConfiguration);
  if (image == null) return;

  final placement = OverlayPlacement.forPoint(
    tracking: context.tracking,
    viewSize: context.size,
    anchorNormalized: anchorNormalized,
    sizeRatio: sizeRatio,
    scaleMultiplier: scaleMultiplier,
  );
  _paintImageAtPlacement(context,
      image: image, placement: placement, opacity: opacity);
}

void _paintImageAtPlacement(
  FaceOverlayPaintContext context, {
  required Image image,
  required OverlayPlacement placement,
  required double opacity,
}) {
  final aspectRatio = image.width / image.height;
  final height = placement.heightFor(aspectRatio.toDouble());
  if (placement.width <= 0 || height <= 0) return;

  final destRect = Rect.fromCenter(
    center: Offset.zero,
    width: placement.width,
    height: height,
  );

  context.canvas
    ..save()
    ..translate(placement.center.dx, placement.center.dy)
    ..rotate(placement.rotation);
  paintImage(
    canvas: context.canvas,
    rect: destRect,
    image: image,
    fit: BoxFit.fill,
    // destRect already matches the image's own aspect ratio (via
    // heightFor), so "fill" doesn't distort anything — it just skips
    // paintImage() re-deriving a fit we've already computed.
    opacity: (opacity * context.opacity).clamp(0.0, 1.0),
  );
  context.canvas.restore();
}
