import 'face_overlay.dart';

/// Signature for [CustomOverlay]'s painter callback.
typedef CustomOverlayPainter = void Function(FaceOverlayPaintContext context);

/// An overlay that delegates painting to an app-supplied callback — the
/// escape hatch for hats, earrings, makeup, and anything else without a
/// built-in overlay type.
///
/// ```dart
/// CustomOverlay(
///   painter: (context) {
///     final center = Offset(
///       context.tracking.forehead!.dx * context.size.width,
///       context.tracking.forehead!.dy * context.size.height,
///     );
///     context.canvas.drawCircle(center, 12, myPaint);
///   },
/// )
/// ```
///
/// For a reusable overlay, extending [FaceOverlay] directly is usually
/// cleaner than wrapping a closure.
class CustomOverlay extends FaceOverlay {
  /// Creates an overlay that paints via [painter].
  const CustomOverlay({required this.painter, super.visibleWhen});

  /// Called each frame under the same contract as [FaceOverlay.paint].
  final CustomOverlayPainter painter;

  @override
  void paint(FaceOverlayPaintContext context) => painter(context);
}
