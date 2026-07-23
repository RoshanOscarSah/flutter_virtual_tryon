import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Generates a small transparent PNG of a simple glasses silhouette at
/// runtime, so the examples are fully self-contained — no bundled binary
/// assets, no network dependency. Real apps would use their own product
/// photography via `AssetImage`/`NetworkImage`/`FileImage`; this exists
/// purely so these demos have *something* to render without shipping
/// artwork in the package.
///
/// [color] lets [opticalShopDemo] generate a few visually distinct
/// "products" from the same shape.
Future<Uint8List> generateGlassesPng({
  Color color = const Color(0xFF1A1A1A),
}) async {
  const width = 300.0;
  const height = 120.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round;

  // Two lens rings.
  const lensRadius = 45.0;
  const leftCenter = Offset(75, 60);
  const rightCenter = Offset(225, 60);
  canvas.drawCircle(leftCenter, lensRadius, paint);
  canvas.drawCircle(rightCenter, lensRadius, paint);
  // Bridge between the lenses.
  canvas.drawLine(
    leftCenter.translate(lensRadius - 5, 0),
    rightCenter.translate(-(lensRadius - 5), 0),
    paint,
  );
  // Temples (arms), suggested rather than fully drawn.
  canvas.drawLine(
    leftCenter.translate(-lensRadius + 5, 0),
    const Offset(0, 45),
    paint,
  );
  canvas.drawLine(
    rightCenter.translate(lensRadius - 5, 0),
    const Offset(width, 45),
    paint,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
