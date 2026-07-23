import 'dart:ui';

import 'package:flutter/widgets.dart' show ImageConfiguration;

import '../models/overlay_constraints.dart';
import '../models/tracking_data.dart';
import '../renderer/overlay_image_resolver.dart';

/// Everything an overlay needs to paint one frame.
///
/// A context object (rather than positional parameters) so the engine can
/// add capabilities in future versions without breaking every [FaceOverlay]
/// implementation in the wild.
class FaceOverlayPaintContext {
  /// Creates a paint context. Constructed by the engine each frame; apps
  /// only construct one directly in tests.
  const FaceOverlayPaintContext({
    required this.canvas,
    required this.size,
    required this.tracking,
    required this.images,
    required this.imageConfiguration,
    this.opacity = 1.0,
    this.mirrored = false,
  });

  /// The canvas to paint on. Already clipped to the widget's bounds.
  final Canvas canvas;

  /// The widget's size in logical pixels. Multiply normalized
  /// [TrackingData] coordinates by this to get canvas positions.
  final Size size;

  /// The face measurement to render against. When the face is lost under
  /// `FaceLossBehavior.freeze`/`fade`/`custom`, this is the last known
  /// measurement.
  final TrackingData tracking;

  /// Global opacity the overlay must multiply into its own — driven by
  /// `FaceLossBehavior.fade`. `1.0` while a face is tracked.
  final double opacity;

  /// Whether the preview (and this canvas) is mirrored (selfie mode).
  /// Mirroring is applied once, above the whole render — overlays normally
  /// don't need to do anything differently; this exists for overlays that
  /// draw text or other orientation-sensitive content that would look
  /// wrong flipped.
  final bool mirrored;

  /// Resolves and caches [ImageProvider]s for overlays that paint images —
  /// what [GlassesOverlay]/[SunglassesOverlay] use internally. Not part of
  /// the documented public API surface (doc/DECISIONS.md #024); a
  /// [CustomOverlay] may use it to avoid reimplementing image resolution,
  /// but its shape may change without a major version bump.
  final OverlayImageResolver images;

  /// Configuration to pass to [images]`.resolve()` — captures device
  /// pixel ratio and similar so, e.g., an [ImageProvider] picks the right
  /// asset variant. Same caveat as [images].
  final ImageConfiguration imageConfiguration;
}

/// Base class for everything that renders onto a tracked face.
///
/// Built-in implementations: `GlassesOverlay`, `SunglassesOverlay`,
/// `ContactLensOverlay`, and `CustomOverlay` for app-defined painting.
/// Third-party overlays extend this class and implement [paint] — the
/// engine handles detection, smoothing, constraint checks, and face-loss
/// behavior; [paint] only draws.
abstract class FaceOverlay {
  /// Const base constructor.
  const FaceOverlay({this.visibleWhen});

  /// Visibility rules evaluated each frame; the engine skips [paint]
  /// entirely when they aren't satisfied. Null means always visible while
  /// a face is tracked.
  final OverlayConstraints? visibleWhen;

  /// Draws this overlay for one frame. Called only while there is tracking
  /// data to render against and [visibleWhen] (if any) is satisfied. Must
  /// not retain [context] or its canvas beyond the call.
  void paint(FaceOverlayPaintContext context);
}
