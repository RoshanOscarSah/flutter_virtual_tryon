import 'package:flutter/material.dart';

import 'demos/calibration_demo.dart';
import 'demos/custom_overlay_demo.dart';
import 'demos/debug_mode_demo.dart';
import 'demos/optical_shop_demo.dart';
import 'demos/quick_start_demo.dart';

void main() {
  runApp(const ExampleApp());
}

/// Root widget for the flutter_virtual_tryon examples — a menu of demos,
/// each showing a different facet of the package (see doc/ROADMAP.md
/// Phase 10 / doc/PRODUCT_REQUIREMENTS.md "Example Applications").
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_virtual_tryon example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _DemoMenu(),
    );
  }
}

class _Demo {
  const _Demo(this.title, this.subtitle, this.builder);
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

final _demos = [
  _Demo(
    'Quick Start',
    'The whole package in a few lines',
    (_) => const QuickStartDemo(),
  ),
  _Demo(
    'Optical Shop',
    'Product grid + live try-on, switching frames',
    (_) => const OpticalShopDemo(),
  ),
  _Demo(
    'Custom Overlay',
    'CustomOverlay drawing with plain Canvas calls',
    (_) => const CustomOverlayDemo(),
  ),
  _Demo(
    'Debug Mode',
    'Every DebugOptions visualization, toggleable',
    (_) => const DebugModeDemo(),
  ),
  _Demo(
    'Calibration',
    'Tune placement live, export ready-to-paste code',
    (_) => const CalibrationDemo(),
  ),
];

class _DemoMenu extends StatelessWidget {
  const _DemoMenu();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_virtual_tryon')),
      body: ListView.separated(
        itemCount: _demos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final demo = _demos[index];
          return ListTile(
            title: Text(demo.title),
            subtitle: Text(demo.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: demo.builder)),
          );
        },
      ),
    );
  }
}
