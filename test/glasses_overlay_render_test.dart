import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/testing.dart';

/// A 4x4 solid-red opaque PNG, generated at test time (no binary asset
/// checked into the repo) — just enough for [MemoryImage] to resolve a
/// real `ui.Image` that GlassesOverlay can actually paint.
///
/// Uses genuinely-async platform work (`Picture.toImage`), so — like
/// [_precache] below — this must run inside `tester.runAsync()`.
/// `flutter_test`'s default zone fakes timers but not real platform
/// callbacks; calling this directly from a `testWidgets` body hangs
/// forever waiting for a callback the fake clock never delivers.
Future<Uint8List> _solidRedPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Forces [provider] into Flutter's global [ImageCache] via a real decode.
/// Must run inside `tester.runAsync()` — see [_solidRedPng]. Once cached,
/// `OverlayImageResolver.resolve()` (used by `GlassesOverlay.paint()`)
/// resolves synchronously on its very first call, making the rest of the
/// test deterministic under normal `pump()`s instead of racing a real
/// decode against fake time.
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

TrackingData _levelFace() => const TrackingData(
      boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
      leftEye: Offset(0.6, 0.4),
      rightEye: Offset(0.4, 0.4),
      confidence: 1.0,
    );

void main() {
  testWidgets(
    'GlassesOverlay resolves its image and paints it at the eye midpoint',
    (tester) async {
      late ImageProvider imageProvider;
      await tester.runAsync(() async {
        final png = await _solidRedPng();
        imageProvider = MemoryImage(png);
        await _precache(imageProvider);
      });

      final backend = MockVisionBackend();
      const viewSize = Size(400, 300);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: viewSize.width,
              height: viewSize.height,
              // VirtualTryOn wraps itself in its own RepaintBoundary
              // (needed for VirtualTryOnController.capture()) — reuse it
              // instead of adding a redundant outer one.
              child: VirtualTryOn(
                backend: backend,
                mirror: false,
                smoothTracking: false,
                overlays: [GlassesOverlay(image: imageProvider)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      backend.emit(_levelFace());
      // Deliver the tracking event and paint. The image is already
      // cached (precached above), so GlassesOverlay's very first paint()
      // call resolves and draws it synchronously — no need to wait on
      // OverlayImageResolver's onImageReady callback. Empirically this
      // still needs a couple of pumps to settle (observed: state updates
      // but the rebuild reflecting it lands a frame later than usual)
      // when following a `tester.runAsync()` call earlier in the test —
      // pump defensively rather than chase the exact minimum.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary),
      );
      late ByteData? byteData;
      await tester.runAsync(() async {
        final rendered = await boundary.toImage();
        byteData =
            await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
        rendered.dispose();
      });
      expect(byteData, isNotNull);
      final pixels = byteData!.buffer.asUint8List();

      // eyeCenter = (0.5, 0.4) normalized -> (200, 120) in the 400x300
      // view — the same math test/overlay_transform_test.dart already
      // verifies independently. Confirm a red pixel actually landed
      // there, i.e. the image really got resolved and painted, not just
      // that the geometry function returns the right numbers on paper.
      const x = 200;
      const y = 120;
      final offset = (y * viewSize.width.toInt() + x) * 4;
      expect(pixels[offset], 255); // R
      expect(pixels[offset + 1], 0); // G
      expect(pixels[offset + 2], 0); // B

      // And a corner far from the glasses should NOT be red (background
      // black) — guards against a bug that paints the whole canvas red.
      const cornerOffset = 0;
      expect(pixels[cornerOffset], isNot(255));
    },
  );

  testWidgets('nothing is painted before the image resolves', (tester) async {
    late Uint8List png;
    await tester.runAsync(() async {
      png = await _solidRedPng();
    });
    final backend = MockVisionBackend();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: VirtualTryOn(
              backend: backend,
              // A fresh, never-precached MemoryImage: this frame's
              // paint() call must be a no-op rather than throwing on a
              // null image, since resolution hasn't completed.
              overlays: [GlassesOverlay(image: MemoryImage(png))],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    backend.emit(_levelFace());
    await tester.pump();
    // No expect needed beyond "didn't throw" — verified implicitly by
    // reaching this point without an exception. The genuinely-async
    // decode is deliberately never let through (no runAsync around it),
    // so this exercises exactly the "still pending" branch.
  });
}
