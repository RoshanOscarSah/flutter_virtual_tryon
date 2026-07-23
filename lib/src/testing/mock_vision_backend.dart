import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../backend/backend_engine.dart';
import '../backend/vision_backend.dart';
import '../models/camera_lens.dart';
import '../models/performance_mode.dart';
import '../models/tracking_data.dart';

/// A scriptable [VisionBackend] for tests: you [emit] tracking data by
/// hand instead of running a camera and ML models.
///
/// ```dart
/// final backend = MockVisionBackend();
/// await tester.pumpWidget(VirtualTryOn(backend: backend, ...));
/// backend.emit(someTrackingData);   // -> onFaceDetected / onFaceUpdated
/// backend.emit(null);               // -> onFaceLost
/// ```
///
/// The mock records lifecycle interactions ([started], [lastLens],
/// [lastPerformanceMode], ...) so tests can assert how the widget drove
/// its backend.
class MockVisionBackend extends VisionBackend implements VisionBackendEngine {
  /// Creates a mock backend.
  ///
  /// Set [supported] false to exercise the `backendUnavailable` path.
  /// [stillResult] is what [detectStill] resolves to (photo-mode tests).
  /// [cameraController], if given, is returned once [start] has been
  /// called (mirroring a real backend, whose controller only exists after
  /// start) — useful for testing that `VirtualTryOn` wires a camera
  /// preview in once one is available. It's never initialized by this
  /// mock; construct it uninitialized (real camera hardware is never
  /// touched) if your test needs one.
  MockVisionBackend({
    bool supported = true,
    this.stillResult,
    CameraController? cameraController,
  })  : _supported = supported,
        _cameraController = cameraController;

  final bool _supported;
  final CameraController? _cameraController;

  /// What [detectStill] returns. Mutable so a test can change it between
  /// calls.
  TrackingData? stillResult;

  final StreamController<TrackingData?> _controller =
      StreamController<TrackingData?>.broadcast();

  /// Whether `ensureReady()` has been called.
  bool readyCalled = false;

  /// Whether the engine is currently started.
  bool started = false;

  /// Whether the engine has been disposed.
  bool disposed = false;

  /// The lens the widget last started with.
  CameraLens? lastLens;

  /// The performance mode the widget last started with.
  PerformanceMode? lastPerformanceMode;

  /// Emits one tracking event, exactly as a real backend would per frame:
  /// a measurement, or null for "frame processed, no face".
  void emit(TrackingData? data) => _controller.add(data);

  /// Emits a stream error, exercising the widget's `backendFailure` path.
  void emitError(Object error) => _controller.addError(error);

  @override
  bool get isSupported => _supported;

  @override
  CameraController? get cameraController => started ? _cameraController : null;

  @override
  Future<void> ensureReady() async {
    readyCalled = true;
  }

  @override
  Future<void> start({
    required CameraLens lens,
    required PerformanceMode performanceMode,
  }) async {
    started = true;
    lastLens = lens;
    lastPerformanceMode = performanceMode;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Stream<TrackingData?> get tracking => _controller.stream;

  @override
  Future<TrackingData?> detectStill(Uint8List bytes) async => stillResult;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}
