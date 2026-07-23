// INTERNAL — not exported. The `dart.library.io` half of the platform
// backend conditional export (see platform_backend.dart): actively drives
// ML Kit + the camera on Android/iOS, and reports itself unsupported
// everywhere else `dart.library.io` is also true (macOS/Windows/Linux —
// see doc/DECISIONS.md #020 for why those get NO auto-detection, not a
// degraded photo-only mode).

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../models/camera_lens.dart';
import '../models/performance_mode.dart';
import '../models/tracking_data.dart';
import '../tracking/fps_tracker.dart';
import 'backend_engine.dart';
import 'ml_kit_conversion.dart';
import 'ml_kit_rotation.dart';

/// Creates the io-platform backend (see file doc comment for scope).
VisionBackendEngine createPlatformBackend() => IoVisionBackendEngine();

/// ML Kit + `camera` backend for Android and iOS.
///
/// Live tracking streams raw sensor frames via
/// [CameraController.startImageStream] (no shutter click, no per-frame
/// capture) and runs them through ML Kit's face detector, throttled so a
/// slow detection never queues up frames behind it. Landmarks come back in
/// the raw sensor buffer's coordinate space; [mlKitFaceToTrackingData]
/// rotates them upright using the same recipe file-path detection already
/// produces, so live and still detection never disagree about where a face
/// is.
final class IoVisionBackendEngine implements VisionBackendEngine {
  FaceDetector? _detector;
  CameraController? _controller;
  final StreamController<TrackingData?> _tracking =
      StreamController<TrackingData?>.broadcast();
  bool _busy = false;
  bool _disposed = false;
  final _fpsTracker = FpsTracker();

  @override
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> ensureReady() async {
    if (!isSupported || _detector != null) return;
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
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
      // nv21/bgra8888 are what mlKitInputImageFromCameraImage expects
      // (single image plane per frame).
      imageFormatGroup: switch (defaultTargetPlatform) {
        TargetPlatform.android => ImageFormatGroup.nv21,
        TargetPlatform.iOS => ImageFormatGroup.bgra8888,
        _ => ImageFormatGroup.jpeg,
      },
    );
    await controller.initialize();
    _controller = controller;
    await controller.startImageStream(
      (image) => _onFrame(image, controller),
    );
  }

  ResolutionPreset _resolutionFor(PerformanceMode mode) => switch (mode) {
        PerformanceMode.fast => ResolutionPreset.low,
        PerformanceMode.balanced => ResolutionPreset.medium,
        PerformanceMode.highAccuracy => ResolutionPreset.high,
      };

  Future<void> _onFrame(CameraImage image, CameraController controller) async {
    final detector = _detector;
    if (_busy || _disposed || detector == null || _tracking.isClosed) return;
    _busy = true;
    try {
      final input = mlKitInputImageFromCameraImage(image, controller);
      if (input == null) {
        if (!_tracking.isClosed) _tracking.add(null);
        return;
      }
      final faces = await detector.processImage(input);
      if (_tracking.isClosed) return;
      final face = pickPrimaryFace(faces);
      final rawSize = ui.Size(image.width.toDouble(), image.height.toDouble());
      final rotation = input.metadata!.rotation;
      final now = DateTime.now();
      final fps = _fpsTracker.tick(now);
      // Platform-split coordinate handling — the crux of getting live
      // landmarks upright (see ml_kit_rotation.dart's recipe note and
      // google_ml_kit's own coordinates_translator.dart):
      //
      //  - iOS: the plugin hands ML Kit an already-display-oriented buffer,
      //    so detections come back upright, in the raw buffer's own
      //    dimensions. Normalize against rawSize and apply NO rotation —
      //    running these through mlKitUprightPoint would rotate an
      //    already-upright face another 90°, stacking the eyes/nose/chin
      //    into a vertical line. The front-camera buffer is also mirrored,
      //    so swapLeftRight relabels ML Kit's left/right landmarks into
      //    TrackingData's unmirrored convention (else eye-anchored overlays
      //    render 180° / upside down — see mlKitFaceToTrackingData's
      //    swapLeftRight note). It's a relabel, not a coordinate flip, so
      //    the overlay stays on the face (a coordinate flip would mirror
      //    its x-position, since the renderer flips preview + overlay
      //    together in the same raw-buffer space).
      //  - Android: detections are in the raw sensor buffer's space, so
      //    rotate them upright (mlKitUprightPoint, via rawSize+rotation) and
      //    normalize against the width/height-swapped upright size.
      final TrackingData? data;
      if (face == null) {
        data = null;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        data = mlKitFaceToTrackingData(
          face,
          rawSize,
          swapLeftRight:
              controller.description.lensDirection == CameraLensDirection.front,
          fps: fps,
          timestamp: now,
        );
      } else {
        data = mlKitFaceToTrackingData(
          face,
          mlKitUprightSize(rawSize, rotation),
          rawSize: rawSize,
          rotation: rotation,
          fps: fps,
          timestamp: now,
        );
      }
      _tracking.add(data);
    } catch (_) {
      // A dropped/malformed frame is not worth surfacing — the next one
      // arrives in well under a second.
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller?.dispose();
  }

  @override
  Stream<TrackingData?> get tracking => _tracking.stream;

  @override
  Future<TrackingData?> detectStill(Uint8List bytes) async {
    if (!isSupported) return null;
    await ensureReady();
    final detector = _detector;
    if (detector == null) return null;

    // The Android/iOS ML Kit bindings only accept a file path, not raw
    // bytes — write a scratch file per call.
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/flutter_virtual_tryon_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    try {
      final imageSize = await _decodeImagePixelSize(bytes);
      if (imageSize == null) return null;
      final input = InputImage.fromFilePath(file.path);
      final faces = await detector.processImage(input);
      final face = pickPrimaryFace(faces);
      return face == null ? null : mlKitFaceToTrackingData(face, imageSize);
    } finally {
      unawaited(file.delete().catchError((_) => file));
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _detector?.close();
    _detector = null;
    await _tracking.close();
  }
}

/// Decodes just far enough to read pixel dimensions — shared canonical
/// "what size image did the detector actually measure" so live and still
/// detection agree on one coordinate space.
Future<ui.Size?> _decodeImagePixelSize(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  } catch (_) {
    return null;
  }
}
