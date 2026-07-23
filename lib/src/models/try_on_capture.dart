import 'dart:typed_data';

/// The result of `VirtualTryOnController.capture()`: the composited
/// try-on frame (camera image plus rendered overlays).
class TryOnCapture {
  /// Creates a capture result.
  const TryOnCapture({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// PNG-encoded image data, ready to save or share.
  final Uint8List bytes;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;
}
