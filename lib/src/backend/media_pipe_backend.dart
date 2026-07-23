// INTERNAL — not exported, web-only. The `dart.library.js_interop` half of
// the platform backend conditional export (see platform_backend.dart).

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../models/camera_lens.dart';
import '../models/performance_mode.dart';
import '../models/tracking_data.dart';
import '../tracking/fps_tracker.dart';
import 'backend_engine.dart';
import 'media_pipe_conversion.dart';
import 'web_bridge.dart';

/// Creates the web platform backend.
VisionBackendEngine createPlatformBackend() => MediaPipeVisionBackendEngine();

/// MediaPipe Face Landmarker backend for web.
///
/// MediaPipe here only detects against a single still frame (see
/// `web_bridge.dart`) — there's no raw-video-frame streaming into Dart, so
/// "live" tracking is simulated by periodically capturing a photo from the
/// (real, `camera_web`-backed) camera preview and detecting each one. This
/// mirrors Kalo Chasma's proven Vision Mirror implementation and keeps the
/// JS interop surface small rather than fighting the `camera` package's
/// internal video element.
final class MediaPipeVisionBackendEngine implements VisionBackendEngine {
  /// How often a still is captured and detected while "live" tracking.
  /// Matches the interval proven in production — see doc/HANDOVER.md.
  static const captureInterval = Duration(milliseconds: 700);

  bool _ready = false;
  bool _loadFailed = false;
  CameraController? _controller;
  Timer? _captureTimer;
  bool _capturing = false;
  final StreamController<TrackingData?> _tracking =
      StreamController<TrackingData?>.broadcast();
  // Only ticked by the live capture loop (_captureAndDetect), not by
  // one-off detectStill() calls — a fps figure only makes sense across
  // repeated "live" frames, not an isolated still detection.
  final _fpsTracker = FpsTracker();

  @override
  bool get isSupported => !_loadFailed;

  @override
  Future<void> ensureReady() async {
    if (_ready || _loadFailed) return;
    try {
      _ready = await webBridgeInit();
      if (!_ready) _loadFailed = true;
    } catch (_) {
      _loadFailed = true;
    }
  }

  @override
  CameraController? get cameraController => _controller;

  @override
  Future<void> start({
    required CameraLens lens,
    required PerformanceMode performanceMode,
  }) async {
    if (!isSupported) return;
    await ensureReady();

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final wanted = lens == CameraLens.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final description = cameras.firstWhere(
      (c) => c.lensDirection == wanted,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      description,
      _resolutionFor(performanceMode),
      enableAudio: false,
    );
    await controller.initialize();
    _controller = controller;

    if (_ready) {
      _captureTimer = Timer.periodic(
        captureInterval,
        (_) => _captureAndDetect(controller),
      );
    }
  }

  ResolutionPreset _resolutionFor(PerformanceMode mode) => switch (mode) {
        PerformanceMode.fast => ResolutionPreset.low,
        PerformanceMode.balanced => ResolutionPreset.medium,
        PerformanceMode.highAccuracy => ResolutionPreset.high,
      };

  Future<void> _captureAndDetect(CameraController controller) async {
    if (_capturing || !controller.value.isInitialized || _tracking.isClosed) {
      return;
    }
    _capturing = true;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final now = DateTime.now();
      final fps = _fpsTracker.tick(now);
      final data = await _detect(bytes, fps: fps, timestamp: now);
      if (!_tracking.isClosed) _tracking.add(data);
    } catch (_) {
      // Transient — the next tick tries again.
    } finally {
      _capturing = false;
    }
  }

  @override
  Future<void> stop() async {
    _captureTimer?.cancel();
    _captureTimer = null;
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Stream<TrackingData?> get tracking => _tracking.stream;

  @override
  Future<TrackingData?> detectStill(Uint8List bytes) => _detect(bytes);

  Future<TrackingData?> _detect(
    Uint8List bytes, {
    double? fps,
    DateTime? timestamp,
  }) async {
    await ensureReady();
    if (!_ready) return null;
    final landmarks = await webBridgeDetect(bytes);
    if (landmarks == null) return null;
    return mediaPipeLandmarksToTrackingData(
      landmarks,
      fps: fps,
      timestamp: timestamp,
    );
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _tracking.close();
  }
}
