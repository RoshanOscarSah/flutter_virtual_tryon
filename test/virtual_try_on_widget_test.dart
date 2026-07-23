import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/src/backend/backend_engine.dart';
import 'package:flutter_virtual_tryon/testing.dart';

/// A [VisionBackend] that does NOT implement the internal
/// [VisionBackendEngine] contract — exercises the "custom backends aren't
/// supported" guard, since [VisionBackend] is an unsealed abstract class a
/// third party could technically extend despite the class doc's warning.
class _UnsupportedCustomBackend extends VisionBackend {}

/// A backend whose [ensureReady] throws, to exercise the widget's
/// initialization-failure path (as opposed to [MockVisionBackend]'s
/// `supported: false`, which exercises the cleaner `backendUnavailable`
/// path instead).
class _ThrowingBackend extends VisionBackend implements VisionBackendEngine {
  @override
  bool get isSupported => true;

  @override
  Future<void> ensureReady() => throw StateError('backend init exploded');

  @override
  Future<void> start({
    required CameraLens lens,
    required PerformanceMode performanceMode,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  CameraController? get cameraController => null;

  @override
  Stream<TrackingData?> get tracking => const Stream.empty();

  @override
  Future<TrackingData?> detectStill(Uint8List bytes) async => null;

  @override
  Future<void> dispose() async {}
}

TrackingData _data({double confidence = 0.9}) => TrackingData(
      boundingBox: const Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
      leftEye: const Offset(0.6, 0.4),
      rightEye: const Offset(0.4, 0.4),
      confidence: confidence,
    );

// Center gives the SizedBox loose constraints — without it the root view's
// tight constraints (the 800x600 test surface) would override our size and
// every pixel-based expectation below would silently test the wrong
// geometry. 400x300 fits inside the surface so nothing clamps.
Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: 400, height: 300, child: child)),
    );

void main() {
  testWidgets('initializes backend and reports onInitialized', (tester) async {
    final backend = MockVisionBackend();
    var initialized = false;
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          cameraLens: CameraLens.back,
          performanceMode: PerformanceMode.highAccuracy,
          onInitialized: () => initialized = true,
        ),
      ),
    );
    await tester.pump();
    expect(backend.readyCalled, isTrue);
    expect(backend.started, isTrue);
    expect(backend.lastLens, CameraLens.back);
    expect(backend.lastPerformanceMode, PerformanceMode.highAccuracy);
    expect(initialized, isTrue);
  });

  testWidgets('unsupported backend surfaces backendUnavailable', (
    tester,
  ) async {
    final backend = MockVisionBackend(supported: false);
    VirtualTryOnException? error;
    var initialized = false;
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          onInitialized: () => initialized = true,
          onError: (e) => error = e,
        ),
      ),
    );
    await tester.pump();
    expect(error?.code, VirtualTryOnErrorCode.backendUnavailable);
    expect(initialized, isFalse);
    expect(backend.started, isFalse);
  });

  testWidgets('detection callbacks fire in order', (tester) async {
    final backend = MockVisionBackend();
    final log = <String>[];
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          onInitialized: () => log.add('init'),
          onFaceDetected: (_) => log.add('detected'),
          onFaceUpdated: (_) => log.add('updated'),
          onFaceLost: () => log.add('lost'),
        ),
      ),
    );
    await tester.pump();
    backend.emit(_data());
    await tester.pump();
    backend.emit(_data(confidence: 0.8));
    await tester.pump();
    backend.emit(null);
    await tester.pump();
    backend.emit(_data());
    await tester.pump();
    expect(log, [
      'init',
      'detected', 'updated', // first sighting
      'updated', // continued tracking: no second onFaceDetected
      'lost',
      'detected', 'updated', // reacquisition fires onFaceDetected again
    ]);
  });

  testWidgets('null frames before first detection do not fire onFaceLost', (
    tester,
  ) async {
    final backend = MockVisionBackend();
    var lost = 0;
    await tester.pumpWidget(
      _host(VirtualTryOn(backend: backend, onFaceLost: () => lost++)),
    );
    await tester.pump();
    backend.emit(null);
    backend.emit(null);
    await tester.pump();
    expect(lost, 0);
  });

  testWidgets('overlays paint with tracking data via the context', (
    tester,
  ) async {
    final backend = MockVisionBackend();
    final contexts = <FaceOverlayPaintContext>[];
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          mirror: false,
          overlays: [CustomOverlay(painter: contexts.add)],
        ),
      ),
    );
    await tester.pump();
    expect(contexts, isEmpty); // nothing to render before a face exists
    final data = _data();
    backend.emit(data);
    await tester.pump(); // deliver the stream event, rebuild
    await tester.pump(); // paint the frame that now contains CustomPaint
    expect(contexts, isNotEmpty);
    expect(contexts.last.tracking, data);
    expect(contexts.last.size, const Size(400, 300));
    expect(contexts.last.opacity, 1.0);
    expect(contexts.last.mirrored, isFalse);
  });

  testWidgets('visibleWhen constraints gate painting', (tester) async {
    final backend = MockVisionBackend();
    var paints = 0;
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          overlays: [
            CustomOverlay(
              // Face renders at 160px wide in a 400px view; demand 300px.
              visibleWhen: const OverlayConstraints(minFaceSize: 300),
              painter: (_) => paints++,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    backend.emit(_data());
    await tester.pump();
    await tester.pump(); // frame where an unconstrained overlay would paint
    expect(paints, 0);
  });

  testWidgets('FaceLossBehavior.hide stops painting on loss', (tester) async {
    final backend = MockVisionBackend();
    final contexts = <FaceOverlayPaintContext>[];
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          overlays: [CustomOverlay(painter: contexts.add)],
        ),
      ),
    );
    await tester.pump();
    backend.emit(_data());
    await tester.pump();
    await tester.pump();
    final paintsWhileTracked = contexts.length;
    expect(paintsWhileTracked, greaterThan(0)); // guard against vacuous pass
    backend.emit(null);
    await tester.pump();
    await tester.pump();
    expect(contexts.length, paintsWhileTracked); // no further paints
  });

  testWidgets('FaceLossBehavior.freeze keeps painting the last data', (
    tester,
  ) async {
    final backend = MockVisionBackend();
    final contexts = <FaceOverlayPaintContext>[];
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          faceLossBehavior: const FaceLossBehavior.freeze(),
          overlays: [CustomOverlay(painter: contexts.add)],
        ),
      ),
    );
    await tester.pump();
    final data = _data();
    backend.emit(data);
    await tester.pump();
    backend.emit(null);
    await tester.pump();
    expect(contexts.last.tracking, data);
    expect(contexts.last.opacity, 1.0);
  });

  testWidgets('FaceLossBehavior.fade drops opacity over its duration', (
    tester,
  ) async {
    final backend = MockVisionBackend();
    final contexts = <FaceOverlayPaintContext>[];
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          faceLossBehavior: const FaceLossBehavior.fade(
            duration: Duration(milliseconds: 200),
          ),
          overlays: [CustomOverlay(painter: contexts.add)],
        ),
      ),
    );
    await tester.pump();
    backend.emit(_data());
    await tester.pump();
    backend.emit(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midFade = contexts.last.opacity;
    expect(midFade, greaterThan(0.0));
    expect(midFade, lessThan(1.0));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    // Fully faded: painting stops entirely.
    final total = contexts.length;
    await tester.pump(const Duration(milliseconds: 50));
    expect(contexts.length, total);
  });

  testWidgets('stream errors surface as backendFailure', (tester) async {
    final backend = MockVisionBackend();
    VirtualTryOnException? error;
    await tester.pumpWidget(
      _host(VirtualTryOn(backend: backend, onError: (e) => error = e)),
    );
    await tester.pump();
    backend.emitError(StateError('detector crashed'));
    await tester.pump();
    expect(error?.code, VirtualTryOnErrorCode.backendFailure);
    expect(error?.cause, isA<StateError>());
  });

  testWidgets('controller exposes tracking state and last data', (
    tester,
  ) async {
    final backend = MockVisionBackend();
    final controller = VirtualTryOnController();
    await tester.pumpWidget(
      _host(VirtualTryOn(backend: backend, controller: controller)),
    );
    await tester.pump();
    expect(controller.trackingState, TrackingState.initializing);
    final data = _data();
    backend.emit(data);
    await tester.pump();
    expect(controller.trackingState, TrackingState.tracking);
    expect(controller.lastTrackingData, data);
    backend.emit(null);
    await tester.pump();
    expect(controller.trackingState, TrackingState.lost);
  });

  test(
    'controller.capture() returns null when never attached to a widget',
    () async {
      // No pumpWidget at all — the frozen contract's "not attached" case.
      // Short-circuits inside capture() itself (no RepaintBoundary/render
      // tree involved), so this doesn't need tester.runAsync().
      final controller = VirtualTryOnController();
      expect(await controller.capture(), isNull);
    },
  );

  testWidgets('controller.capture() snapshots the composited frame', (
    tester,
  ) async {
    final backend = MockVisionBackend();
    final controller = VirtualTryOnController();
    TryOnCapture? delivered;
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          controller: controller,
          onCapture: (c) => delivered = c,
        ),
      ),
    );
    await tester.pump();
    backend.emit(_data());
    await tester.pump();

    late TryOnCapture? result;
    // toImage() does real platform rasterization work that flutter_test's
    // fake-async zone never completes on its own — see
    // glasses_overlay_render_test.dart for the same gotcha.
    await tester.runAsync(() async {
      result = await controller.capture();
    });

    expect(result, isNotNull);
    expect(result!.width, greaterThan(0));
    expect(result!.height, greaterThan(0));
    expect(result!.bytes, isNotEmpty);
    // PNG magic bytes.
    expect(result!.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(delivered, same(result));
  });

  testWidgets('widget disposes the backend it was given', (tester) async {
    final backend = MockVisionBackend();
    await tester.pumpWidget(_host(VirtualTryOn(backend: backend)));
    await tester.pump();
    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pump();
    expect(backend.started, isFalse);
    expect(backend.disposed, isTrue);
  });

  testWidgets(
    'a VisionBackend that does not implement the internal engine contract '
    'reports backendUnavailable',
    (tester) async {
      VirtualTryOnException? error;
      await tester.pumpWidget(
        _host(
          VirtualTryOn(
            backend: _UnsupportedCustomBackend(),
            onError: (e) => error = e,
          ),
        ),
      );
      await tester.pump();
      expect(error?.code, VirtualTryOnErrorCode.backendUnavailable);
      expect(error?.message, contains('not supported'));
    },
  );

  testWidgets(
    'toggling smoothTracking off then on gives a fresh smoother, not a '
    'stale one',
    (tester) async {
      final backend = MockVisionBackend();
      await tester.pumpWidget(
        _host(VirtualTryOn(backend: backend, smoothTracking: true)),
      );
      await tester.pump();
      backend.emit(_data());
      await tester.pump();

      await tester.pumpWidget(
        _host(VirtualTryOn(backend: backend, smoothTracking: false)),
      );
      await tester.pump();

      await tester.pumpWidget(
        _host(VirtualTryOn(backend: backend, smoothTracking: true)),
      );
      await tester.pump();
      // Doesn't throw, and keeps tracking normally — the assertion here is
      // just that this sequence completes without error; the smoother's
      // internal state reset isn't independently observable from outside.
      backend.emit(_data());
      await tester.pump();
    },
  );

  testWidgets('debugMode paints without a tracked face and with one', (
    tester,
  ) async {
    final backend = MockVisionBackend();
    await tester.pumpWidget(
      _host(
        VirtualTryOn(
          backend: backend,
          debugMode: true,
          debugOptions: const DebugOptions.all(),
        ),
      ),
    );
    await tester.pump();
    backend.emit(_data());
    await tester.pump();
    // Doesn't throw either before or after a face is tracked.
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend initialization failure surfaces backendFailure', (
    tester,
  ) async {
    VirtualTryOnException? error;
    await tester.pumpWidget(
      _host(
        VirtualTryOn(backend: _ThrowingBackend(), onError: (e) => error = e),
      ),
    );
    await tester.pump();
    expect(error?.code, VirtualTryOnErrorCode.backendFailure);
    expect(error?.cause, isA<StateError>());
  });

  testWidgets(
    'reassigning controller across a rebuild detaches the old one',
    (tester) async {
      final backend = MockVisionBackend();
      final controllerA = VirtualTryOnController();
      final controllerB = VirtualTryOnController();
      await tester.pumpWidget(
        _host(VirtualTryOn(backend: backend, controller: controllerA)),
      );
      await tester.pump();
      backend.emit(_data());
      await tester.pump();
      expect(controllerA.trackingState, TrackingState.tracking);

      await tester.pumpWidget(
        _host(VirtualTryOn(backend: backend, controller: controllerB)),
      );
      await tester.pump();
      backend.emit(_data());
      await tester.pump();

      // The new controller reflects live state; the detached one no longer
      // updates (it reports the un-attached default, not what backend.emit
      // just produced).
      expect(controllerB.lastTrackingData, isNotNull);
      expect(controllerA.trackingState, TrackingState.initializing);
    },
  );

  testWidgets(
    'switching to a different backend type tears down the old one and '
    'starts the new one',
    (tester) async {
      final backendA = MockVisionBackend();
      final backendB = _ThrowingBackend();
      await tester.pumpWidget(_host(VirtualTryOn(backend: backendA)));
      await tester.pump();
      expect(backendA.started, isTrue);

      VirtualTryOnException? error;
      await tester.pumpWidget(
        _host(VirtualTryOn(backend: backendB, onError: (e) => error = e)),
      );
      await tester.pump();

      expect(backendA.disposed, isTrue);
      expect(error?.code, VirtualTryOnErrorCode.backendFailure);
    },
  );
}
