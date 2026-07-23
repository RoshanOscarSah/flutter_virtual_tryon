import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart' show CameraPreview;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../backend/backend_engine.dart';
import '../backend/vision_backend.dart';
import '../models/camera_lens.dart';
import '../models/debug_options.dart';
import '../models/face_loss_behavior.dart';
import '../models/performance_mode.dart';
import '../models/tracking_data.dart';
import '../models/tracking_state.dart';
import '../models/try_on_capture.dart';
import '../models/try_on_error.dart';
import '../overlays/face_overlay.dart';
import '../renderer/overlay_image_resolver.dart';
import '../renderer/overlays_painter.dart';
import '../tracking/tracking_smoother.dart';

/// Imperative handle for a [VirtualTryOn] widget: capture and state
/// queries that don't fit the declarative build.
///
/// ```dart
/// final controller = VirtualTryOnController();
/// // ...
/// VirtualTryOn(controller: controller, overlays: [...]);
/// // ...
/// final shot = await controller.capture();
/// ```
///
/// Attach one controller to at most one [VirtualTryOn] at a time.
class VirtualTryOnController {
  _VirtualTryOnState? _state;

  /// The engine's current tracking state. [TrackingState.initializing]
  /// when not attached to a widget yet.
  TrackingState get trackingState =>
      _state?._trackingState ?? TrackingState.initializing;

  /// The most recent face measurement (smoothed, if `smoothTracking` is
  /// on), or null if no face has been tracked yet.
  TrackingData? get lastTrackingData => _state?._lastData;

  /// Captures the current composited frame (camera + overlays, including
  /// the debug overlay if `debugMode` is on) as a PNG.
  ///
  /// Returns null when capture isn't currently possible — not attached, no
  /// frame rendered yet, or the platform can't snapshot. Also delivered to
  /// `VirtualTryOn.onCapture` when non-null.
  Future<TryOnCapture?> capture() async => _state?._capture();
}

/// The face-tracking try-on view: camera preview with [FaceOverlay]s
/// rendered onto the tracked face.
///
/// The minimal use is a few lines:
///
/// ```dart
/// VirtualTryOn(
///   overlays: [
///     GlassesOverlay(image: AssetImage('assets/rayban.png')),
///   ],
/// )
/// ```
///
/// Lifecycle callbacks fire in this order: [onInitialized] once the
/// backend is ready and the camera started; then per detection
/// [onFaceDetected] (first sight or reacquisition after loss) and
/// [onFaceUpdated] (every measurement); [onFaceLost] when the face
/// disappears, with visuals governed by [faceLossBehavior]. Failures
/// surface through [onError] — including
/// [VirtualTryOnErrorCode.backendUnavailable] on platforms with no live
/// tracking backend, where the widget still renders but no tracking
/// callbacks fire.
class VirtualTryOn extends StatefulWidget {
  /// Creates a try-on view.
  const VirtualTryOn({
    super.key,
    this.backend,
    this.cameraLens = CameraLens.front,
    this.mirror = true,
    this.smoothTracking = true,
    this.performanceMode = PerformanceMode.balanced,
    this.faceLossBehavior = const FaceLossBehavior.hide(),
    this.debugMode = false,
    this.debugOptions = const DebugOptions(),
    this.overlays = const <FaceOverlay>[],
    this.controller,
    this.onInitialized,
    this.onFaceDetected,
    this.onFaceUpdated,
    this.onFaceLost,
    this.onCapture,
    this.onError,
  });

  /// Which vision implementation to use. Defaults to [VisionBackend.auto].
  /// The widget owns the backend's lifecycle — don't share one instance
  /// between widgets.
  final VisionBackend? backend;

  /// Which camera drives the preview. Defaults to the front camera.
  final CameraLens cameraLens;

  /// Mirror the preview horizontally (natural for selfie view). Applied to
  /// both the camera image and the overlays as one unit, so they stay in
  /// sync. Only affects rendering — [TrackingData] coordinates stay
  /// unmirrored.
  final bool mirror;

  /// Smooth tracking output to suppress jitter, at the cost of a few
  /// frames of latency. See doc/ARCHITECTURE.md's smoothing engine.
  final bool smoothTracking;

  /// Speed/quality trade-off passed to the backend.
  final PerformanceMode performanceMode;

  /// What happens to overlays when the face is lost.
  final FaceLossBehavior faceLossBehavior;

  /// Master switch for the built-in diagnostic overlay.
  final bool debugMode;

  /// Which diagnostics to draw when [debugMode] is on.
  final DebugOptions debugOptions;

  /// The overlays to render onto the tracked face, painted in list order
  /// (last on top).
  final List<FaceOverlay> overlays;

  /// Optional imperative handle for capture and state queries.
  final VirtualTryOnController? controller;

  /// Backend ready and camera started; tracking callbacks may now fire.
  final VoidCallback? onInitialized;

  /// A face was sighted — fires on first detection and on each
  /// reacquisition after loss, before that measurement's [onFaceUpdated].
  final void Function(TrackingData data)? onFaceDetected;

  /// Every face measurement, typically once per processed camera frame.
  final void Function(TrackingData data)? onFaceUpdated;

  /// The tracked face disappeared. Always fires regardless of
  /// [faceLossBehavior].
  final VoidCallback? onFaceLost;

  /// A capture completed (see [VirtualTryOnController.capture]).
  final void Function(TryOnCapture capture)? onCapture;

  /// Something failed. See [VirtualTryOnErrorCode] for the categories.
  final void Function(VirtualTryOnException error)? onError;

  @override
  State<VirtualTryOn> createState() => _VirtualTryOnState();
}

class _VirtualTryOnState extends State<VirtualTryOn>
    with SingleTickerProviderStateMixin {
  VisionBackendEngine? _engine;
  StreamSubscription<TrackingData?>? _subscription;
  TrackingData? _lastData;
  TrackingState _trackingState = TrackingState.initializing;
  late final AnimationController _fadeOpacity;
  TrackingSmoother? _smoother;
  late final OverlayImageResolver _images;
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fadeOpacity = AnimationController(vsync: this, value: 1.0)
      ..addListener(() => setState(() {}));
    _images = OverlayImageResolver(onImageReady: () => setState(() {}));
    if (widget.smoothTracking) _smoother = TrackingSmoother();
    widget.controller?._state = this;
    unawaited(_initBackend());
  }

  @override
  void didUpdateWidget(VirtualTryOn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (oldWidget.smoothTracking != widget.smoothTracking) {
      // A fresh smoother (rather than toggling a flag on the old one)
      // means turning smoothing back on never blends against a stale,
      // possibly long-gone sample.
      _smoother = widget.smoothTracking ? TrackingSmoother() : null;
    }
    // Rebuilds routinely construct fresh `VisionBackend.auto()` instances
    // (the documented usage puts the call in build). Only a *type* change
    // signals a genuinely different backend worth restarting for.
    if (oldWidget.backend.runtimeType != widget.backend.runtimeType) {
      unawaited(_teardownBackend().then((_) => _initBackend()));
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    unawaited(_teardownBackend());
    _fadeOpacity.dispose();
    _images.dispose();
    super.dispose();
  }

  Future<void> _initBackend() async {
    final backend = widget.backend ?? VisionBackend.auto();
    if (backend is! VisionBackendEngine) {
      _emitError(
        VirtualTryOnErrorCode.backendUnavailable,
        'Custom VisionBackend implementations are not supported; use '
        'VisionBackend.auto().',
      );
      return;
    }
    // `is!` can't promote to an unrelated interface type, hence the cast.
    final engine = backend as VisionBackendEngine;
    _engine = engine;
    try {
      await engine.ensureReady();
      if (!mounted || _engine != engine) return;
      if (!engine.isSupported) {
        _emitError(
          VirtualTryOnErrorCode.backendUnavailable,
          'No live face-tracking backend is available on this platform.',
        );
        return;
      }
      _subscription = engine.tracking.listen(
        _handleTracking,
        onError: (Object error) {
          _emitError(
            VirtualTryOnErrorCode.backendFailure,
            'The vision backend reported an error while tracking.',
            error,
          );
        },
      );
      await engine.start(
        lens: widget.cameraLens,
        performanceMode: widget.performanceMode,
      );
      if (!mounted || _engine != engine) return;
      // The camera controller (if any) only exists after start() —
      // rebuild so build() picks up engine.cameraController.
      setState(() {});
      widget.onInitialized?.call();
    } catch (error) {
      _emitError(
        VirtualTryOnErrorCode.backendFailure,
        'The vision backend failed to initialize.',
        error,
      );
    }
  }

  Future<void> _teardownBackend() async {
    final engine = _engine;
    _engine = null;
    // Deliberately not awaited: a broadcast subscription stops delivering
    // as soon as cancel() is called, but its returned future can complete
    // arbitrarily late (observed hanging teardown under fake-async tests).
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (engine != null) {
      await engine.stop();
      await engine.dispose();
    }
  }

  void _handleTracking(TrackingData? data) {
    if (!mounted) return;
    if (data == null) {
      if (_trackingState != TrackingState.tracking) return;
      setState(() => _trackingState = TrackingState.lost);
      _smoother?.reset();
      final behavior = widget.faceLossBehavior;
      if (behavior is FadeFaceLossBehavior) {
        _fadeOpacity.animateTo(
          0.0,
          duration: behavior.duration,
          curve: Curves.easeOut,
        );
      }
      widget.onFaceLost?.call();
      return;
    }
    final reacquired = _trackingState != TrackingState.tracking;
    final smoothed = _smoother?.smooth(data) ?? data;
    setState(() {
      _trackingState = TrackingState.tracking;
      _lastData = smoothed;
    });
    if (reacquired) {
      _fadeOpacity.value = 1.0;
      widget.onFaceDetected?.call(smoothed);
    }
    widget.onFaceUpdated?.call(smoothed);
  }

  void _emitError(
    VirtualTryOnErrorCode code,
    String message, [
    Object? cause,
  ]) {
    if (!mounted) return;
    widget.onError?.call(VirtualTryOnException(code, message, cause));
  }

  Future<TryOnCapture?> _capture() async {
    final renderObject = _boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    try {
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      // Read dimensions before dispose() — a disposed ui.Image's
      // properties aren't guaranteed accessible afterward.
      final width = image.width;
      final height = image.height;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;
      final result = TryOnCapture(
        bytes: byteData.buffer.asUint8List(),
        width: width,
        height: height,
      );
      widget.onCapture?.call(result);
      return result;
    } catch (_) {
      // toImage() can throw if the boundary hasn't painted yet or the
      // engine can't rasterize right now — capture failing is a normal,
      // documented outcome (returns null), not a crash.
      return null;
    }
  }

  /// What the overlay painter should render right now, or null for nothing.
  (TrackingData, double)? get _renderInstruction {
    switch (_trackingState) {
      case TrackingState.initializing:
        return null;
      case TrackingState.tracking:
        return (_lastData!, 1.0);
      case TrackingState.lost:
        final data = _lastData;
        if (data == null) return null;
        return switch (widget.faceLossBehavior) {
          HideFaceLossBehavior() => null,
          FreezeFaceLossBehavior() => (data, 1.0),
          CustomFaceLossBehavior() => (data, 1.0),
          FadeFaceLossBehavior() =>
            _fadeOpacity.value == 0.0 ? null : (data, _fadeOpacity.value),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final instruction = _renderInstruction;
    final cameraController = _engine?.cameraController;

    Widget content =
        cameraController != null && cameraController.value.isInitialized
            ? CameraPreview(cameraController)
            // No camera available yet (still starting) or ever (platform has
            // no live backend — VirtualTryOnErrorCode.backendUnavailable
            // already fired via onError). A plain surface either way; apps
            // wanting a styled placeholder layer their own UI underneath.
            : const ColoredBox(color: Color(0xFF000000));

    return RepaintBoundary(
      key: _boundaryKey,
      child: ClipRect(
        child: Transform.flip(
          flipX: widget.mirror,
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (instruction != null)
                CustomPaint(
                  painter: OverlaysPainter(
                    overlays: widget.overlays,
                    data: instruction.$1,
                    opacity: instruction.$2,
                    mirrored: widget.mirror,
                    images: _images,
                    imageConfiguration: createLocalImageConfiguration(
                      context,
                    ),
                  ),
                ),
              if (widget.debugMode)
                CustomPaint(
                  // Painted inside the same mirror transform as the camera
                  // image and overlays, so its position markers (face box,
                  // landmarks, ...) line up with what's actually on screen
                  // — correct alignment is the point of a debugging aid.
                  // Trade-off: the text panel (FPS/rotation/scale/
                  // confidence) reads mirrored too when `mirror` is on.
                  painter: DebugPainter(
                    options: widget.debugOptions,
                    tracking: _trackingState == TrackingState.tracking
                        ? _lastData
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
