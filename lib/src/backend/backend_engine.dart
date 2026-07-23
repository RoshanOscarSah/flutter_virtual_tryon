// INTERNAL — not exported from the package. This is the operational
// contract the VirtualTryOn widget drives; VisionBackend instances that
// reach the widget must also implement this interface. Keeping it out of
// the public library is what lets the contract evolve (M2 wires the real
// camera + detectors through here) without public API changes.

import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../models/camera_lens.dart';
import '../models/performance_mode.dart';
import '../models/tracking_data.dart';

/// Operational contract between the widget and a vision backend.
abstract interface class VisionBackendEngine {
  /// False when this backend cannot do live tracking here (wrong platform,
  /// missing plugin). The widget then reports `backendUnavailable`.
  bool get isSupported;

  /// Loads models/plugins. Safe to call repeatedly; cheap once ready.
  Future<void> ensureReady();

  /// Begins producing [tracking] events, opening the camera in the
  /// process (see [cameraController]).
  Future<void> start({
    required CameraLens lens,
    required PerformanceMode performanceMode,
  });

  /// Stops producing events and releases the camera.
  Future<void> stop();

  /// A measurement per processed frame, or null when a frame contained no
  /// face. Broadcast; listenable across restarts.
  Stream<TrackingData?> get tracking;

  /// The live camera controller opened by [start], once initialized. Null
  /// before start, after stop/dispose, or on backends with no camera
  /// preview (e.g. a not-yet-started or platform-unsupported engine). The
  /// renderer (M3) reads this to show a live preview; it's not part of the
  /// public API.
  CameraController? get cameraController;

  /// Detects the most prominent face in a still image (photo mode). Null
  /// when unsupported or no face found.
  Future<TrackingData?> detectStill(Uint8List bytes);

  /// Releases everything. The engine is unusable afterwards.
  Future<void> dispose();
}
