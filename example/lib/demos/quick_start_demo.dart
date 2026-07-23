import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

import '../demo_glasses.dart';

/// The minimal use case: a live camera preview with one overlay. This is
/// the whole package in a few lines.
///
/// The [FutureBuilder] here only exists because this demo *generates* its
/// glasses artwork at runtime instead of shipping a bundled asset (see
/// demo_glasses.dart) — a real app just writes:
///
/// ```dart
/// VirtualTryOn(
///   overlays: [
///     GlassesOverlay(image: AssetImage('assets/rayban.png')),
///   ],
/// )
/// ```
class QuickStartDemo extends StatelessWidget {
  /// Creates the quick-start demo screen.
  const QuickStartDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Start')),
      body: FutureBuilder<Uint8List>(
        future: generateGlassesPng(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return VirtualTryOn(
            overlays: [GlassesOverlay(image: MemoryImage(bytes))],
            onError: (error) => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.message))),
          );
        },
      ),
    );
  }
}
