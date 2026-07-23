/// Machine-readable category for a [VirtualTryOnException].
enum VirtualTryOnErrorCode {
  /// No vision backend is available on this platform (e.g. live tracking
  /// on desktop). The widget still renders; tracking callbacks won't fire.
  backendUnavailable,

  /// The user denied camera permission, or it is restricted by policy.
  cameraPermissionDenied,

  /// No usable camera was found, or the camera failed to start.
  cameraUnavailable,

  /// `VirtualTryOnController.capture()` failed to produce an image.
  captureFailed,

  /// The vision backend threw while initializing or processing frames.
  backendFailure,
}

/// The error type delivered to `VirtualTryOn.onError`.
///
/// Never silently swallowed: everything the engine can't handle internally
/// surfaces here with a [code] the app can switch on and a human-readable
/// [message] for logs.
class VirtualTryOnException implements Exception {
  /// Creates an exception with a machine-readable [code], a developer-facing
  /// [message], and optionally the underlying [cause].
  const VirtualTryOnException(this.code, this.message, [this.cause]);

  /// What went wrong, as a category apps can branch on.
  final VirtualTryOnErrorCode code;

  /// Developer-facing description with actionable detail.
  final String message;

  /// The underlying error, when this wraps one.
  final Object? cause;

  @override
  String toString() => 'VirtualTryOnException(${code.name}): $message'
      '${cause == null ? '' : ' (cause: $cause)'}';
}
