import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

import '../demo_glasses.dart';

/// Demonstrates [OverlayCalibrator] — the development-time tool for
/// tuning `GlassesOverlay` placement by dragging/pinching/twisting it
/// against your own face, then exporting the result as Dart code (see
/// doc/PRODUCT_REQUIREMENTS.md's "Calibration Mode").
class CalibrationDemo extends StatelessWidget {
  /// Creates the calibration demo screen.
  const CalibrationDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      body: FutureBuilder<Uint8List>(
        future: generateGlassesPng(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return OverlayCalibrator(
            image: MemoryImage(bytes),
            // In a real app this would name the actual asset/network
            // expression backing `image` above, since the two can't be
            // derived from each other.
            imageExpression: "AssetImage('assets/rayban.png')",
          );
        },
      ),
    );
  }
}
