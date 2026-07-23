import 'package:flutter/material.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

/// Demonstrates [CustomOverlay] — the escape hatch for anything that
/// isn't an image. This draws a star above the tracked face with plain
/// `Canvas` calls, sized and positioned from [TrackingData] directly.
///
/// Deliberately anchors from [TrackingData.leftEye]/[rightEye] rather
/// than an optional landmark like `forehead` — those two are the only
/// ones every backend guarantees (see doc/API.md), so this demo behaves
/// the same on every platform instead of only rendering on web (where
/// MediaPipe happens to report a forehead point and ML Kit doesn't).
class CustomOverlayDemo extends StatelessWidget {
  /// Creates the custom-overlay demo screen.
  const CustomOverlayDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Overlay')),
      body: VirtualTryOn(overlays: [CustomOverlay(painter: _paintStar)]),
    );
  }

  static void _paintStar(FaceOverlayPaintContext context) {
    final tracking = context.tracking;
    final size = context.size;

    // Same pixel-space approach OverlayPlacement uses internally
    // (doc/DECISIONS.md #024's sibling reasoning): convert to local
    // pixels before measuring, so a non-square view doesn't skew it.
    final leftEyePx = Offset(
      tracking.leftEye.dx * size.width,
      tracking.leftEye.dy * size.height,
    );
    final rightEyePx = Offset(
      tracking.rightEye.dx * size.width,
      tracking.rightEye.dy * size.height,
    );
    final eyeCenterPx = Offset.lerp(leftEyePx, rightEyePx, 0.5)!;
    final eyeDistancePx = (rightEyePx - leftEyePx).distance;

    // A rough "above the eyes" anchor built from guaranteed data, since
    // this demo doesn't rely on the optional forehead landmark.
    final starCenter = eyeCenterPx.translate(0, -eyeDistancePx * 1.4);
    final starSize = eyeDistancePx * 1.2;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '⭐',
        style: TextStyle(
          fontSize: starSize,
          color: Colors.amber.withValues(alpha: context.opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      context.canvas,
      starCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
}
