import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/testing.dart';

/// A 4x4 solid-blue opaque PNG, generated at test time. See
/// glasses_overlay_render_test.dart for why this (and [_precache] below)
/// need `tester.runAsync()`.
Future<Uint8List> _solidBluePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFF0000FF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> _precache(ImageProvider provider) {
  final completer = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      stream.removeListener(listener);
      completer.complete();
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

Future<Uint8List> _capturePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  late ByteData? byteData;
  await tester.runAsync(() async {
    final rendered = await boundary.toImage();
    byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
  });
  return byteData!.buffer.asUint8List();
}

const _viewSize = Size(400, 300);

int _pixelOffset(int x, int y) => (y * _viewSize.width.toInt() + x) * 4;

void main() {
  testWidgets(
    'ContactLensOverlay anchors on the iris when iris landmarks are '
    'available',
    (tester) async {
      late ImageProvider imageProvider;
      await tester.runAsync(() async {
        final png = await _solidBluePng();
        imageProvider = MemoryImage(png);
        await _precache(imageProvider);
      });
      final backend = MockVisionBackend();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: _viewSize.width,
              height: _viewSize.height,
              child: VirtualTryOn(
                backend: backend,
                mirror: false,
                smoothTracking: false,
                overlays: [ContactLensOverlay(leftTexture: imageProvider)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      backend.emit(
        const TrackingData(
          boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
          leftEye: Offset(0.6, 0.4),
          rightEye: Offset(0.4, 0.4),
          leftIris: Offset(0.65, 0.42), // deliberately off from leftEye
          confidence: 1.0,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final pixels = await _capturePixels(tester);
      // leftIris (0.65, 0.42) -> (260, 126) — the lens should be there.
      final irisPx = _pixelOffset(260, 126);
      expect(pixels[irisPx], 0); // R
      expect(pixels[irisPx + 2], 255); // B

      // leftEye (0.6, 0.4) -> (240, 120) — NOT where the lens should be,
      // proving it anchored on the iris rather than falling back.
      final eyePx = _pixelOffset(240, 120);
      expect(pixels[eyePx + 2], isNot(255));
    },
  );

  testWidgets(
    'ContactLensOverlay falls back to the eye center when iris landmarks '
    'are unavailable',
    (tester) async {
      late ImageProvider imageProvider;
      await tester.runAsync(() async {
        final png = await _solidBluePng();
        imageProvider = MemoryImage(png);
        await _precache(imageProvider);
      });
      final backend = MockVisionBackend();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: _viewSize.width,
              height: _viewSize.height,
              child: VirtualTryOn(
                backend: backend,
                mirror: false,
                smoothTracking: false,
                overlays: [ContactLensOverlay(leftTexture: imageProvider)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      backend.emit(
        const TrackingData(
          boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
          leftEye: Offset(0.6, 0.4),
          rightEye: Offset(0.4, 0.4),
          // No leftIris/rightIris — ML Kit-shaped detection.
          confidence: 1.0,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final pixels = await _capturePixels(tester);
      // leftEye (0.6, 0.4) -> (240, 120): the fallback anchor.
      final eyePx = _pixelOffset(240, 120);
      expect(pixels[eyePx], 0); // R
      expect(pixels[eyePx + 2], 255); // B
    },
  );

  testWidgets('a texture-less eye is left untouched', (tester) async {
    late ImageProvider imageProvider;
    await tester.runAsync(() async {
      final png = await _solidBluePng();
      imageProvider = MemoryImage(png);
      await _precache(imageProvider);
    });
    final backend = MockVisionBackend();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: _viewSize.width,
            height: _viewSize.height,
            child: VirtualTryOn(
              backend: backend,
              mirror: false,
              smoothTracking: false,
              // Only leftTexture provided — rightTexture stays null.
              overlays: [ContactLensOverlay(leftTexture: imageProvider)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    backend.emit(
      const TrackingData(
        boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
        leftEye: Offset(0.6, 0.4),
        rightEye: Offset(0.4, 0.4),
        confidence: 1.0,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final pixels = await _capturePixels(tester);
    // rightEye (0.4, 0.4) -> (160, 120): no texture there.
    final rightEyePx = _pixelOffset(160, 120);
    expect(pixels[rightEyePx + 2], isNot(255));
  });

  testWidgets(
    'rightTexture paints on the right eye, independent of leftTexture',
    (tester) async {
      late ImageProvider imageProvider;
      await tester.runAsync(() async {
        final png = await _solidBluePng();
        imageProvider = MemoryImage(png);
        await _precache(imageProvider);
      });
      final backend = MockVisionBackend();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: _viewSize.width,
              height: _viewSize.height,
              child: VirtualTryOn(
                backend: backend,
                mirror: false,
                smoothTracking: false,
                // Only rightTexture provided this time.
                overlays: [ContactLensOverlay(rightTexture: imageProvider)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      backend.emit(
        const TrackingData(
          boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
          leftEye: Offset(0.6, 0.4),
          rightEye: Offset(0.4, 0.4),
          rightIris: Offset(0.38, 0.41), // deliberately off from rightEye
          confidence: 1.0,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final pixels = await _capturePixels(tester);
      // rightIris (0.38, 0.41) -> (152, 123) — the lens should be there.
      final irisPx = _pixelOffset(152, 123);
      expect(pixels[irisPx], 0); // R
      expect(pixels[irisPx + 2], 255); // B

      // leftEye (0.6, 0.4) -> (240, 120): no texture there.
      final leftEyePx = _pixelOffset(240, 120);
      expect(pixels[leftEyePx + 2], isNot(255));
    },
  );
}
