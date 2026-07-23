// INTERNAL — not exported. Draws VirtualTryOn.debugOptions'
// visualizations. Always painted above every FaceOverlay, never gated by
// visibleWhen (a debugging aid should stay visible even when an overlay
// hides itself).

import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import '../models/debug_options.dart';
import '../models/tracking_data.dart';

const _boxColor = Color(0xFF00E676);
const _landmarkColor = Color(0xFFFFEA00);
const _eyeColor = Color(0xFF2979FF);
const _anchorColor = Color(0xFFFF1744);
const _textBackground = Color(0xAA000000);

/// Paints [options]' enabled visualizations for [tracking] onto [canvas],
/// which is [size] logical pixels — same coordinate contract as
/// `FaceOverlayPaintContext`. Every value (including FPS, from
/// [TrackingData.fps]) comes from [tracking]; when it's null (no face
/// tracked yet, or ever) the text panel shows placeholders rather than
/// hiding entirely, so `debugMode` gives an honest "nothing detected"
/// signal instead of just disappearing.
void paintDebugOverlay(
  Canvas canvas,
  Size size, {
  required DebugOptions options,
  TrackingData? tracking,
}) {
  if (tracking != null) {
    _paintTrackingVisualizations(canvas, size, options, tracking);
  }
  _paintTextPanel(canvas, size, options, tracking);
}

void _paintTrackingVisualizations(
  Canvas canvas,
  Size size,
  DebugOptions options,
  TrackingData tracking,
) {
  Offset toPx(Offset normalized) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  if (options.showFaceBox) {
    final box = tracking.boundingBox;
    canvas.drawRect(
      Rect.fromLTRB(
        box.left * size.width,
        box.top * size.height,
        box.right * size.width,
        box.bottom * size.height,
      ),
      Paint()
        ..color = _boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  if (options.showLandmarks) {
    final landmarkPaint = Paint()..color = _landmarkColor;
    for (final point in [
      tracking.leftIris,
      tracking.rightIris,
      tracking.nose,
      tracking.chin,
      tracking.forehead,
      tracking.leftEar,
      tracking.rightEar,
    ]) {
      if (point != null) canvas.drawCircle(toPx(point), 4, landmarkPaint);
    }
  }

  if (options.showEyeCenters) {
    final eyePaint = Paint()..color = _eyeColor;
    canvas.drawCircle(toPx(tracking.leftEye), 5, eyePaint);
    canvas.drawCircle(toPx(tracking.rightEye), 5, eyePaint);
  }

  if (options.showAnchors) {
    canvas.drawCircle(
      toPx(tracking.eyeCenter),
      6,
      Paint()
        ..color = _anchorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

void _paintTextPanel(
  Canvas canvas,
  Size size,
  DebugOptions options,
  TrackingData? tracking,
) {
  final fps = tracking?.fps;
  final lines = <String>[
    if (options.showFPS) 'FPS: ${fps == null ? '—' : fps.toStringAsFixed(1)}',
    if (options.showRotation)
      'Rotation: ${tracking == null ? '—' : '${tracking.rotation.toStringAsFixed(1)}°'}',
    if (options.showScale)
      'Scale: ${tracking == null ? '—' : tracking.scale.toStringAsFixed(3)}',
    if (options.showTrackingConfidence)
      'Confidence: ${tracking == null ? '—' : tracking.confidence.toStringAsFixed(2)}',
  ];
  if (lines.isEmpty) return;

  final painter = TextPainter(
    text: TextSpan(
      text: lines.join('\n'),
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 12,
        height: 1.4,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width - 16);

  const origin = Offset(8, 8);
  final backgroundRect = Rect.fromLTWH(
    origin.dx - 4,
    origin.dy - 4,
    painter.width + 8,
    painter.height + 8,
  );
  canvas.drawRect(backgroundRect, Paint()..color = _textBackground);
  painter.paint(canvas, origin);
}
