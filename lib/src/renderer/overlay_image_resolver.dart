// Not exported from the package's public barrel (flutter_virtual_tryon.dart)
// — reachable only via FaceOverlayPaintContext.images, which documents it
// as an implementation detail. See doc/DECISIONS.md #024.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Resolves [ImageProvider]s into paintable [ui.Image]s and caches them
/// across frames, for overlays that draw images via `Canvas` (the built-in
/// architecture — see doc/DECISIONS.md #003 — means overlays can't just
/// drop in an `Image.asset()` widget).
///
/// [resolve] never blocks: it returns the cached image immediately once
/// resolution completes, and null on every call before that (kicking off
/// resolution on the first such call). [onImageReady] fires once a
/// resolution completes so the caller can trigger a repaint — a `Canvas`
/// has no way to "wait" for an image mid-frame.
///
/// One instance is owned per [VirtualTryOn] (see `virtual_try_on.dart`)
/// and lives for the widget's lifetime, so the same `AssetImage('x.png')`
/// passed on every rebuild only resolves once. Built-in overlays
/// (`GlassesOverlay`, `SunglassesOverlay`) use this internally; a
/// [CustomOverlay] that paints images may use the same instance via
/// `FaceOverlayPaintContext.images` instead of reimplementing image
/// resolution.
///
/// There's no eviction policy — every distinct [ImageProvider] resolved
/// during a session stays cached until [dispose]. Deliberate for 0.1.0:
/// typical usage resolves a handful of product images, not an unbounded
/// stream of them. Revisit if that assumption turns out wrong.
class OverlayImageResolver {
  /// Creates a resolver. [onImageReady] is called (possibly many times)
  /// whenever a previously-unresolved image becomes available.
  OverlayImageResolver({required this.onImageReady});

  /// Called after a [resolve] call that previously returned null now has
  /// an image ready. Not called synchronously from within [resolve].
  final VoidCallback onImageReady;

  final Map<ImageProvider, ui.Image> _resolved = <ImageProvider, ui.Image>{};
  final Map<ImageProvider, (ImageStream, ImageStreamListener)> _pending =
      <ImageProvider, (ImageStream, ImageStreamListener)>{};
  bool _disposed = false;

  /// The resolved image for [provider] under [configuration], or null if
  /// it isn't ready yet.
  ui.Image? resolve(ImageProvider provider, ImageConfiguration configuration) {
    final cached = _resolved[provider];
    if (cached != null) return cached;
    if (_pending.containsKey(provider)) return null;

    final stream = provider.resolve(configuration);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        _pending.remove(provider);
        stream.removeListener(listener);
        if (_disposed) {
          // Nothing left to notify or retain an image for.
          return;
        }
        // .clone() gives an independently-owned handle we control the
        // lifetime of — the ImageInfo/stream's own reference is released
        // once we stop listening, per Flutter's documented image
        // lifecycle contract.
        _resolved[provider] = info.image.clone();
        // A synchronous hit (image already in Flutter's ImageCache)
        // completes within this same resolve() call, which itself runs
        // from inside paint() — the check below picks it up before
        // returning, so notifying here would call setState mid-paint.
        if (!synchronousCall) onImageReady();
      },
      onError: (Object error, StackTrace? stackTrace) {
        _pending.remove(provider);
        stream.removeListener(listener);
      },
    );
    _pending[provider] = (stream, listener);
    stream.addListener(listener);
    // Populated synchronously above if the image was already cached.
    return _resolved[provider];
  }

  /// Releases every resolved image and detaches from any still-pending
  /// resolutions. The resolver is unusable afterwards.
  void dispose() {
    _disposed = true;
    for (final image in _resolved.values) {
      image.dispose();
    }
    _resolved.clear();
    for (final (stream, listener) in _pending.values) {
      stream.removeListener(listener);
    }
    _pending.clear();
  }
}
