import 'package:flutter/material.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

/// Demonstrates the built-in diagnostic overlay (`debugMode` +
/// `debugOptions`) — invaluable for debugging alignment while
/// integrating the package (see doc/ARCHITECTURE.md's "Debug System").
/// Every [DebugOptions] flag is toggleable live so you can see exactly
/// what each one draws.
class DebugModeDemo extends StatefulWidget {
  /// Creates the debug-mode demo screen.
  const DebugModeDemo({super.key});

  @override
  State<DebugModeDemo> createState() => _DebugModeDemoState();
}

class _DebugModeDemoState extends State<DebugModeDemo> {
  var _options = const DebugOptions.all();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Mode')),
      body: Column(
        children: [
          Expanded(
            child: VirtualTryOn(debugMode: true, debugOptions: _options),
          ),
          SafeArea(
            top: false,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                _toggleChip(
                  'FPS',
                  _options.showFPS,
                  (v) => setState(() => _options = _copyWith(showFPS: v)),
                ),
                _toggleChip(
                  'Face box',
                  _options.showFaceBox,
                  (v) => setState(() => _options = _copyWith(showFaceBox: v)),
                ),
                _toggleChip(
                  'Landmarks',
                  _options.showLandmarks,
                  (v) => setState(() => _options = _copyWith(showLandmarks: v)),
                ),
                _toggleChip(
                  'Eye centers',
                  _options.showEyeCenters,
                  (v) =>
                      setState(() => _options = _copyWith(showEyeCenters: v)),
                ),
                _toggleChip(
                  'Anchors',
                  _options.showAnchors,
                  (v) => setState(() => _options = _copyWith(showAnchors: v)),
                ),
                _toggleChip(
                  'Rotation',
                  _options.showRotation,
                  (v) => setState(() => _options = _copyWith(showRotation: v)),
                ),
                _toggleChip(
                  'Scale',
                  _options.showScale,
                  (v) => setState(() => _options = _copyWith(showScale: v)),
                ),
                _toggleChip(
                  'Confidence',
                  _options.showTrackingConfidence,
                  (v) => setState(
                    () => _options = _copyWith(showTrackingConfidence: v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DebugOptions _copyWith({
    bool? showFPS,
    bool? showFaceBox,
    bool? showLandmarks,
    bool? showEyeCenters,
    bool? showAnchors,
    bool? showRotation,
    bool? showScale,
    bool? showTrackingConfidence,
  }) {
    return DebugOptions(
      showFPS: showFPS ?? _options.showFPS,
      showFaceBox: showFaceBox ?? _options.showFaceBox,
      showLandmarks: showLandmarks ?? _options.showLandmarks,
      showEyeCenters: showEyeCenters ?? _options.showEyeCenters,
      showAnchors: showAnchors ?? _options.showAnchors,
      showRotation: showRotation ?? _options.showRotation,
      showScale: showScale ?? _options.showScale,
      showTrackingConfidence:
          showTrackingConfidence ?? _options.showTrackingConfidence,
    );
  }

  Widget _toggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: FilterChip(
        label: Text(label),
        selected: value,
        onSelected: onChanged,
      ),
    );
  }
}
