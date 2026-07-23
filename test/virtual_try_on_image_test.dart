import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/testing.dart';

/// A solid-color PNG of the given pixel size, generated at test time (no
/// binary asset in the repo). Genuinely-async (`Picture.toImage`), so it
/// must run inside `tester.runAsync()`.
Future<Uint8List> _solidPng(int w, int h, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Forces [provider] into Flutter's global ImageCache so
/// `OverlayImageResolver.resolve()` returns synchronously on first paint.
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

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: 400, height: 300, child: child)),
    );

void main() {
  testWidgets(
    'detects a face and paints the overlay over the photo',
    (tester) async {
      late Uint8List photoBytes;
      late ImageProvider overlayImage;
      await tester.runAsync(() async {
        // 400x300 white photo -> AspectRatio fills the 400x300 host exactly.
        photoBytes = await _solidPng(400, 300, const Color(0xFFFFFFFF));
        overlayImage =
            MemoryImage(await _solidPng(4, 4, const Color(0xFFFF0000)));
        // Precache both so Image.memory(photo) and the overlay both paint
        // synchronously by capture time (else the undecoded photo leaves the
        // background black rather than white).
        await _precache(MemoryImage(photoBytes));
        await _precache(overlayImage);
      });

      final backend = MockVisionBackend(stillResult: _levelFace());
      TrackingData? detected;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _host(
            VirtualTryOnImage(
              backend: backend,
              imageBytes: photoBytes,
              overlays: [GlassesOverlay(image: overlayImage)],
              onFaceDetected: (d) => detected = d,
            ),
          ),
        );
        // Let initState's _detect() finish: decode size + detectStill.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(detected, isNotNull);

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
      final pixels = byteData!.buffer.asUint8List();
      int at(int x, int y) => (y * 400 + x) * 4;

      // eyeCenter (0.5, 0.4) -> (200, 120): the red overlay lands here
      // (green channel 0 distinguishes the red glasses from the white photo).
      final center = at(200, 120);
      expect(pixels[center], 255); // R
      expect(pixels[center + 1], 0); // G — overlay, not the white photo
      expect(pixels[center + 2], 0); // B

      // A corner shows the white photo (overlay absent): green channel 255.
      expect(pixels[at(2, 2) + 1], 255);
    },
  );

  testWidgets(
    'no face detected shows noFaceBuilder and does not call onFaceDetected',
    (tester) async {
      late Uint8List photoBytes;
      await tester.runAsync(() async {
        photoBytes = await _solidPng(400, 300, const Color(0xFFFFFFFF));
      });
      final backend = MockVisionBackend(); // stillResult defaults to null
      var faceCalls = 0;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _host(
            VirtualTryOnImage(
              backend: backend,
              imageBytes: photoBytes,
              overlays: const [],
              onFaceDetected: (_) => faceCalls++,
              noFaceBuilder: (_) => const Text('No face found'),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('No face found'), findsOneWidget);
      expect(faceCalls, 0);
    },
  );

  testWidgets(
    'unsupported backend surfaces backendUnavailable via onError',
    (tester) async {
      late Uint8List photoBytes;
      await tester.runAsync(() async {
        photoBytes = await _solidPng(400, 300, const Color(0xFFFFFFFF));
      });
      final backend = MockVisionBackend(supported: false);
      VirtualTryOnException? error;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _host(
            VirtualTryOnImage(
              backend: backend,
              imageBytes: photoBytes,
              overlays: const [],
              onError: (e) => error = e,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(error?.code, VirtualTryOnErrorCode.backendUnavailable);
    },
  );
}
