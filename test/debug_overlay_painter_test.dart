import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/src/renderer/debug_overlay_painter.dart';

TrackingData _data({double? fps}) => TrackingData(
      boundingBox: const Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
      leftEye: const Offset(0.6, 0.4),
      rightEye: const Offset(0.4, 0.4),
      confidence: 0.75,
      nose: const Offset(0.5, 0.55),
      fps: fps,
    );

/// Renders [paint] into a [size]-sized raster and returns its RGBA bytes.
/// A plain (non-widget) canvas render — no widget tree, no image
/// resolution, so unlike glasses_overlay_render_test.dart this needs
/// `tester.runAsync()` only for the `toImage`/`toByteData` calls
/// themselves, which is why every test below is still `testWidgets`.
Future<Uint8List> _render(
  void Function(Canvas canvas, Size size) paint,
  Size size,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

int _pixelOffset(Size size, int x, int y) => (y * size.width.toInt() + x) * 4;

void main() {
  const size = Size(200, 200);

  testWidgets('nothing is drawn when every option is off', (tester) async {
    late Uint8List pixels;
    await tester.runAsync(() async {
      pixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(),
          tracking: _data(),
        ),
        size,
      );
    });
    // Fully transparent everywhere: alpha channel is 0 for every pixel.
    for (var i = 3; i < pixels.length; i += 4) {
      expect(pixels[i], 0, reason: 'pixel at byte $i should be transparent');
    }
  });

  testWidgets('showFaceBox draws a rect outline at the bounding box', (
    tester,
  ) async {
    late Uint8List pixels;
    await tester.runAsync(() async {
      pixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(showFaceBox: true),
          tracking: _data(),
        ),
        size,
      );
    });
    // boundingBox left edge = 0.3 * 200 = 60; top-to-bottom spans a
    // vertical stroke there. A point on that edge should be opaque.
    final onEdge = _pixelOffset(size, 60, 100);
    expect(pixels[onEdge + 3], greaterThan(0));
    // The box interior (well inside the stroke) should be untouched.
    final interior = _pixelOffset(size, 100, 100);
    expect(pixels[interior + 3], 0);
  });

  testWidgets('showEyeCenters marks both eyes', (tester) async {
    late Uint8List pixels;
    await tester.runAsync(() async {
      pixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(showEyeCenters: true),
          tracking: _data(),
        ),
        size,
      );
    });
    // leftEye (0.6, 0.4) -> (120, 80); rightEye (0.4, 0.4) -> (80, 80).
    expect(pixels[_pixelOffset(size, 120, 80) + 3], greaterThan(0));
    expect(pixels[_pixelOffset(size, 80, 80) + 3], greaterThan(0));
    // showAnchors was off, so the eye *midpoint* (100, 80) shouldn't be
    // separately marked by this option alone.
  });

  testWidgets(
      'showAnchors marks the eye midpoint, distinct from '
      'showEyeCenters', (tester) async {
    late Uint8List pixels;
    await tester.runAsync(() async {
      pixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(showAnchors: true),
          tracking: _data(),
        ),
        size,
      );
    });
    // eyeCenter = (0.5, 0.4) -> (100, 80); the anchor marker is a ring
    // (stroked circle), so its edge (not necessarily the exact center) is
    // opaque — check a point on the expected stroke radius.
    final onRing = _pixelOffset(size, 106, 80); // center + radius(6)
    expect(pixels[onRing + 3], greaterThan(0));
  });

  testWidgets('showLandmarks marks present optional landmarks', (
    tester,
  ) async {
    late Uint8List pixels;
    await tester.runAsync(() async {
      pixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(showLandmarks: true),
          tracking: _data(),
        ),
        size,
      );
    });
    // nose = (0.5, 0.55) -> (100, 110).
    expect(pixels[_pixelOffset(size, 100, 110) + 3], greaterThan(0));
  });

  testWidgets(
      'text panel draws a background block when any text option '
      'is on', (tester) async {
    late Uint8List onPixels;
    late Uint8List offPixels;
    await tester.runAsync(() async {
      onPixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(showFPS: true),
          tracking: _data(fps: 30),
        ),
        size,
      );
      offPixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(),
          tracking: _data(fps: 30),
        ),
        size,
      );
    });
    // Top-left corner (inside the panel's background rect) is opaque only
    // when the panel is actually drawn.
    final corner = _pixelOffset(size, 4, 4);
    expect(onPixels[corner + 3], greaterThan(0));
    expect(offPixels[corner + 3], 0);
  });

  testWidgets(
      'null tracking still draws the text panel with placeholders, '
      'but no position markers', (tester) async {
    late Uint8List pixels;
    await tester.runAsync(() async {
      pixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(showFPS: true, showFaceBox: true),
          tracking: null,
        ),
        size,
      );
    });
    // Panel background still drawn.
    expect(pixels[_pixelOffset(size, 4, 4) + 3], greaterThan(0));
    // But no face box (there's no tracking data to draw one from).
    expect(pixels[_pixelOffset(size, 60, 100) + 3], 0);
  });

  testWidgets(
      'null tracking falls back to placeholders for rotation/scale/'
      'confidence too', (tester) async {
    late Uint8List pixels;
    await tester.runAsync(() async {
      pixels = await _render(
        (Canvas canvas, Size s) => paintDebugOverlay(
          canvas,
          s,
          options: const DebugOptions(
            showRotation: true,
            showScale: true,
            showTrackingConfidence: true,
          ),
          tracking: null,
        ),
        size,
      );
    });
    // Doesn't throw, and still draws the panel background — the placeholder
    // text itself isn't pixel-checked (font rendering varies by platform).
    expect(pixels[_pixelOffset(size, 4, 4) + 3], greaterThan(0));
  });
}
