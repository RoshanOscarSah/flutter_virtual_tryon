import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/src/renderer/overlay_image_resolver.dart';

/// A 2x2 solid-red PNG, generated at test time — see
/// glasses_overlay_render_test.dart for why decoding it needs
/// `tester.runAsync()`.
Future<Uint8List> _solidPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 2, 2),
    Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  testWidgets(
    'resolve() returns null until ready, then the cached image; '
    'onImageReady fires exactly once',
    (tester) async {
      late Uint8List bytes;
      await tester.runAsync(() async => bytes = await _solidPng());
      var readyCount = 0;
      final resolver = OverlayImageResolver(onImageReady: () => readyCount++);
      final provider = MemoryImage(bytes);

      expect(resolver.resolve(provider, ImageConfiguration.empty), isNull);
      // A second resolve() call while the first is pending must not start a
      // duplicate stream (dedup via _pending) — still null, no throw.
      expect(resolver.resolve(provider, ImageConfiguration.empty), isNull);

      await tester.runAsync(() async {
        // Poll resolve() itself rather than a fixed delay — deterministic,
        // no arbitrary sleep duration to tune.
        while (resolver.resolve(provider, ImageConfiguration.empty) == null) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      expect(resolver.resolve(provider, ImageConfiguration.empty), isNotNull);
      expect(readyCount, 1);

      resolver.dispose();
    },
  );

  testWidgets(
    'dispose() before resolution completes releases the pending listener '
    'without calling onImageReady',
    (tester) async {
      late Uint8List bytes;
      await tester.runAsync(() async => bytes = await _solidPng());
      var readyCount = 0;
      final resolver = OverlayImageResolver(onImageReady: () => readyCount++);
      final provider = MemoryImage(bytes);

      resolver.resolve(provider, ImageConfiguration.empty);
      resolver.dispose();

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      expect(readyCount, 0);
    },
  );

  testWidgets(
    'a provider that fails to decode leaves the resolver usable (onError '
    'path clears the pending entry instead of caching or throwing)',
    (tester) async {
      final resolver = OverlayImageResolver(onImageReady: () {});
      // Empty bytes: not a valid image, decode fails asynchronously.
      final badProvider = MemoryImage(Uint8List(0));

      expect(resolver.resolve(badProvider, ImageConfiguration.empty), isNull);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      // Never resolved; a later call re-attempts rather than staying stuck
      // "pending" forever.
      expect(resolver.resolve(badProvider, ImageConfiguration.empty), isNull);

      resolver.dispose();
    },
  );
}
