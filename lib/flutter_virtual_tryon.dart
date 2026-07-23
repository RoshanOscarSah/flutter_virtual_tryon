/// A cross-platform face tracking and overlay engine for Flutter.
///
/// The entry point is the [VirtualTryOn] widget:
///
/// ```dart
/// VirtualTryOn(
///   overlays: [
///     GlassesOverlay(image: AssetImage('assets/rayban.png')),
///   ],
/// )
/// ```
///
/// Computer-vision backends (ML Kit, MediaPipe, ...) stay hidden behind
/// [VisionBackend.auto]. See doc/API.md for the full frozen surface and
/// `package:flutter_virtual_tryon/testing.dart` for camera-free testing
/// utilities.
library;

export 'src/backend/vision_backend.dart' show VisionBackend;
export 'src/calibration/calibration_controller.dart';
export 'src/models/camera_lens.dart';
export 'src/models/debug_options.dart';
export 'src/models/face_loss_behavior.dart';
export 'src/models/overlay_constraints.dart';
export 'src/models/performance_mode.dart';
export 'src/models/tracking_data.dart';
export 'src/models/tracking_state.dart';
export 'src/models/try_on_capture.dart';
export 'src/models/try_on_error.dart';
export 'src/overlays/contact_lens_overlay.dart';
export 'src/overlays/custom_overlay.dart';
export 'src/overlays/face_overlay.dart';
export 'src/overlays/glasses_overlay.dart';
export 'src/overlays/sunglasses_overlay.dart';
export 'src/widgets/overlay_calibrator.dart';
export 'src/widgets/virtual_try_on.dart';
export 'src/widgets/virtual_try_on_image.dart';
