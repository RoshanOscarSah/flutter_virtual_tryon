import 'glasses_overlay.dart';

/// Renders a sunglasses image anchored to the tracked eyes.
///
/// Identical placement API to [GlassesOverlay] (doc/API.md defines them as
/// same-API); it exists as its own type so catalogs can distinguish product
/// categories and so future sunglasses-specific rendering (e.g. lens tint
/// effects) has a home that isn't a breaking change.
class SunglassesOverlay extends GlassesOverlay {
  /// Creates a sunglasses overlay for
  /// [image](GlassesOverlay.image).
  const SunglassesOverlay({
    required super.image,
    super.scaleMultiplier,
    super.offset,
    super.rotationOffset,
    super.opacity,
    super.visibleWhen,
  });
}
