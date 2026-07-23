// INTERNAL — not exported. The VisionBackend.auto() implementation.

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../models/camera_lens.dart';
import '../models/performance_mode.dart';
import '../models/tracking_data.dart';
import 'backend_engine.dart';
import 'platform_backend.dart';
import 'vision_backend.dart';

/// Platform-selecting backend behind [VisionBackend.auto].
///
/// Delegates every call to the real, platform-specific engine chosen by
/// `platform_backend.dart`'s conditional export: ML Kit + camera on
/// Android/iOS, MediaPipe + camera on web. On other platforms (macOS,
/// Windows, Linux) the underlying engine reports itself unsupported — see
/// doc/DECISIONS.md #020.
final class AutoVisionBackend extends VisionBackend
    implements VisionBackendEngine {
  /// Creates the platform-selecting backend.
  AutoVisionBackend() : _delegate = createPlatformBackend();

  final VisionBackendEngine _delegate;

  @override
  bool get isSupported => _delegate.isSupported;

  @override
  Future<void> ensureReady() => _delegate.ensureReady();

  @override
  CameraController? get cameraController => _delegate.cameraController;

  @override
  Future<void> start({
    required CameraLens lens,
    required PerformanceMode performanceMode,
  }) =>
      _delegate.start(lens: lens, performanceMode: performanceMode);

  @override
  Future<void> stop() => _delegate.stop();

  @override
  Stream<TrackingData?> get tracking => _delegate.tracking;

  @override
  Future<TrackingData?> detectStill(Uint8List bytes) =>
      _delegate.detectStill(bytes);

  @override
  Future<void> dispose() => _delegate.dispose();
}
