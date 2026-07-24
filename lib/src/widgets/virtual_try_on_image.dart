import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../backend/backend_engine.dart';
import '../backend/vision_backend.dart';
import '../models/tracking_data.dart';
import '../models/try_on_error.dart';
import '../overlays/face_overlay.dart';
import '../renderer/overlay_image_resolver.dart';
import '../renderer/overlays_painter.dart';

/// The still-photo sibling of `VirtualTryOn`: detects a face **once** in a
/// supplied photo and paints [overlays] over it, instead of tracking a live
/// camera feed. Use it for a gallery pick, a captured photo, or any static
/// image.
///
/// ```dart
/// VirtualTryOnImage(
///   imageBytes: await pickedFile.readAsBytes(),
///   overlays: [GlassesOverlay(image: AssetImage('assets/rayban.png'))],
/// )
/// ```
///
/// [imageBytes] is the *encoded* photo (JPEG/PNG bytes) — the same thing
/// `image_picker`, `File.readAsBytes`, and `rootBundle.load` return. Encoded
/// bytes (not an `ImageProvider`) because face detection needs them: ML Kit
/// reads a real image file and MediaPipe a blob.
///
/// The photo and overlays render inside an [AspectRatio] locked to the
/// image's own dimensions, so the widget sizes itself to the photo and the
/// overlays land in the right place with no letterboxing math. Place it in a
/// bounded box (e.g. inside `Expanded`/`Center`) like any `AspectRatio`.
///
/// A normal photo isn't selfie-mirrored, so [mirror] defaults to false
/// (unlike the live preview). A photo that *was* saved mirrored (some
/// front-camera selfies) may place overlays as a mirror image.
class VirtualTryOnImage extends StatefulWidget {
  /// Creates a still-image try-on view for [imageBytes].
  const VirtualTryOnImage({
    super.key,
    required this.imageBytes,
    required this.overlays,
    this.backend,
    this.mirror = false,
    this.mirroredSource = false,
    this.loadingBuilder,
    this.noFaceBuilder,
    this.onFaceDetected,
    this.onError,
  });

  /// The encoded photo (JPEG/PNG) to detect a face in and display.
  final Uint8List imageBytes;

  /// Overlays to paint over the detected face, in order.
  final List<FaceOverlay> overlays;

  /// The vision backend. Defaults to [VisionBackend.auto].
  final VisionBackend? backend;

  /// Whether to mirror the photo and overlays horizontally. Defaults to
  /// false — unlike the live selfie preview, a saved photo isn't mirrored.
  final bool mirror;

  /// Set true when the supplied photo was captured *mirrored* — most
  /// commonly a front-camera selfie saved with iOS's "Mirror Front Camera"
  /// setting. Such a photo reports its eyes on the opposite sides from the
  /// unmirrored convention, so eyewear overlays would otherwise render
  /// reversed/upside-down. This relabels the detected left/right landmarks
  /// ([TrackingData.swapLeftRight]) so frames face the right way, *without*
  /// flipping the displayed photo (the subject still sees their familiar
  /// selfie). Distinct from [mirror], which flips the display itself.
  ///
  /// There's no reliable metadata that says a photo was mirrored, so expose
  /// this as a user-facing "flip" control rather than guessing. Defaults to
  /// false (a normal photo).
  final bool mirroredSource;

  /// Built while detection is running. Defaults to a centered blank box.
  final WidgetBuilder? loadingBuilder;

  /// Built when detection finishes but finds no face. When null, the photo
  /// is shown on its own (no overlays).
  final WidgetBuilder? noFaceBuilder;

  /// Called once with the measurement when a face is detected.
  final ValueChanged<TrackingData>? onFaceDetected;

  /// Called if the backend is unavailable or detection fails.
  final ValueChanged<VirtualTryOnException>? onError;

  @override
  State<VirtualTryOnImage> createState() => _VirtualTryOnImageState();
}

class _VirtualTryOnImageState extends State<VirtualTryOnImage> {
  late OverlayImageResolver _images;
  VisionBackendEngine? _engine;

  TrackingData? _tracking;
  ui.Size? _imageSize;
  bool _detecting = true;
  // Guards against a stale async detection (from an old photo) overwriting a
  // newer one when [imageBytes] changes mid-flight.
  int _detectionToken = 0;

  @override
  void initState() {
    super.initState();
    _images = OverlayImageResolver(
      onImageReady: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_detect());
  }

  @override
  void didUpdateWidget(VirtualTryOnImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-detect when the photo changes or a genuinely different backend is
    // supplied. Identity check on the bytes: callers pass a new list per
    // photo (image_picker etc.), and deep-comparing every byte each rebuild
    // isn't worth it.
    if (!identical(oldWidget.imageBytes, widget.imageBytes) ||
        oldWidget.backend.runtimeType != widget.backend.runtimeType) {
      unawaited(_detect());
    }
  }

  Future<void> _detect() async {
    final token = ++_detectionToken;
    if (mounted) setState(() => _detecting = true);

    final backend = widget.backend ?? VisionBackend.auto();
    if (backend is! VisionBackendEngine) {
      _emitError(
        VirtualTryOnErrorCode.backendUnavailable,
        'Custom VisionBackend implementations are not supported; use '
        'VisionBackend.auto().',
      );
      if (mounted && token == _detectionToken) {
        setState(() => _detecting = false);
      }
      return;
    }
    final engine = backend as VisionBackendEngine;
    _engine = engine;

    ui.Size? size;
    TrackingData? tracking;
    try {
      await engine.ensureReady();
      if (!mounted || token != _detectionToken) return;
      if (!engine.isSupported) {
        _emitError(
          VirtualTryOnErrorCode.backendUnavailable,
          'No face-detection backend is available on this platform.',
        );
      } else {
        size = await _decodePixelSize(widget.imageBytes);
        tracking = await engine.detectStill(widget.imageBytes);
      }
    } catch (error) {
      _emitError(
        VirtualTryOnErrorCode.backendFailure,
        'The vision backend failed to process the image.',
        error,
      );
    }

    if (!mounted || token != _detectionToken) return;
    setState(() {
      _tracking = tracking;
      _imageSize = size;
      _detecting = false;
    });
    if (tracking != null) widget.onFaceDetected?.call(tracking);
  }

  void _emitError(
    VirtualTryOnErrorCode code,
    String message, [
    Object? cause,
  ]) {
    if (!mounted) return;
    widget.onError?.call(VirtualTryOnException(code, message, cause));
  }

  @override
  void dispose() {
    _images.dispose();
    unawaited(_engine?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    if (_detecting || size == null) {
      return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }

    if (_tracking == null && widget.noFaceBuilder != null) {
      return widget.noFaceBuilder!(context);
    }

    // A mirrored-source photo (a front-camera selfie) reports left/right
    // landmarks reversed; relabel them so eyewear faces the right way. Pure
    // transform of already-detected data — toggling [mirroredSource] repaints
    // instantly with no re-detection.
    final detected = _tracking;
    final tracking = detected != null && widget.mirroredSource
        ? detected.swapLeftRight()
        : detected;
    return AspectRatio(
      aspectRatio: size.width / size.height,
      child: RepaintBoundary(
        child: ClipRect(
          child: Transform.flip(
            flipX: widget.mirror,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // BoxFit.fill is safe: the AspectRatio box matches the
                // image's aspect ratio exactly, so nothing distorts — and
                // it lets normalized tracking coords map linearly to the box.
                Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
                if (tracking != null)
                  CustomPaint(
                    painter: OverlaysPainter(
                      overlays: widget.overlays,
                      data: tracking,
                      opacity: 1.0,
                      mirrored: widget.mirror,
                      images: _images,
                      imageConfiguration:
                          createLocalImageConfiguration(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decodes just the pixel dimensions of an encoded image. Null if the bytes
/// aren't a decodable image.
Future<ui.Size?> _decodePixelSize(Uint8List bytes) async {
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
