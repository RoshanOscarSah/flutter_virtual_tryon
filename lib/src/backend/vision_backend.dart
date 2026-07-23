import 'auto_vision_backend.dart';

/// Selects which computer-vision implementation powers the try-on engine.
///
/// The concrete implementations (ML Kit on Android/iOS, MediaPipe on web,
/// and whatever ships next) are deliberately not part of the public API —
/// they can be replaced without a breaking change, and their types never
/// leak into yours.
///
/// ```dart
/// VirtualTryOn(
///   backend: VisionBackend.auto(),
///   // ...
/// )
/// ```
///
/// Implementing or extending [VisionBackend] outside this package is not
/// supported: the engine binds to internal contracts that third-party
/// subclasses can't fulfill, and `VirtualTryOn` will report
/// `VirtualTryOnErrorCode.backendUnavailable` for such instances. Custom
/// backends are a planned post-1.0 extension point.
abstract class VisionBackend {
  /// Const base constructor for the package's internal implementations.
  const VisionBackend();

  /// Picks the best available backend for the current platform: ML Kit on
  /// Android and iOS, MediaPipe on web, photo-based detection where no
  /// live backend exists. Never throws — on unsupported platforms the
  /// widget surfaces `backendUnavailable` through `onError` instead.
  factory VisionBackend.auto() = AutoVisionBackend;
}
