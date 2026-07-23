import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../backend/vision_backend.dart';
import '../calibration/calibration_controller.dart';
import '../models/camera_lens.dart';
import '../overlays/face_overlay.dart';
import '../overlays/glasses_overlay.dart';
import '../overlays/sunglasses_overlay.dart';
import 'virtual_try_on.dart';

/// A development-time tool for visually tuning [GlassesOverlay]/
/// [SunglassesOverlay] placement and exporting the result as Dart code —
/// doc/PRODUCT_REQUIREMENTS.md's "Calibration Mode".
///
/// Wrap it around your target image during development, drag/pinch/twist
/// the overlay until it looks right against your own face, then copy the
/// generated constructor call into your app. Not meant to ship in a
/// production build — it's a tuning tool, not a runtime feature.
///
/// ```dart
/// OverlayCalibrator(
///   image: AssetImage('assets/rayban.png'),
///   imageExpression: "AssetImage('assets/rayban.png')",
/// )
/// ```
///
/// [imageExpression] is the literal Dart source to embed in the exported
/// snippet — it can't be derived from [image] in general (an
/// [AssetImage] doesn't know its own constructor call once built), so
/// you provide both: [image] to render live, [imageExpression] to quote
/// back.
class OverlayCalibrator extends StatefulWidget {
  /// Creates a calibration view for [image].
  const OverlayCalibrator({
    super.key,
    required this.image,
    required this.imageExpression,
    this.overlayType = CalibrationOverlayType.glasses,
    this.controller,
    this.backend,
    this.cameraLens = CameraLens.front,
  });

  /// The overlay artwork, rendered live while calibrating.
  final ImageProvider image;

  /// Dart source for [image]'s expression, quoted verbatim into the
  /// exported snippet — e.g. `"AssetImage('assets/rayban.png')"`.
  final String imageExpression;

  /// Which overlay type the exported snippet constructs.
  final CalibrationOverlayType overlayType;

  /// Optional external controller — supply one to read calibrated values
  /// programmatically (e.g. to persist them) instead of only via the
  /// on-screen export panel. A default is created and owned internally
  /// when omitted.
  final CalibrationController? controller;

  /// Forwarded to the underlying [VirtualTryOn]. Defaults to
  /// [VisionBackend.auto].
  final VisionBackend? backend;

  /// Forwarded to the underlying [VirtualTryOn].
  final CameraLens cameraLens;

  @override
  State<OverlayCalibrator> createState() => _OverlayCalibratorState();
}

class _OverlayCalibratorState extends State<OverlayCalibrator> {
  CalibrationController? _ownedController;
  double _baseScale = 1.0;
  double _baseRotationDegrees = 0.0;

  CalibrationController get _controller =>
      widget.controller ?? (_ownedController ??= CalibrationController());

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _controller.scaleMultiplier;
    _baseRotationDegrees = _controller.rotationOffset;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // ScaleUpdateDetails' scale/rotation are cumulative since onScaleStart,
    // not incremental per callback — combine with the values captured at
    // gesture start rather than the controller's current (already-updated
    // this gesture) values, or each frame would compound on itself.
    _controller.update(
      scaleMultiplier: _baseScale * details.scale,
      rotationOffset:
          _baseRotationDegrees + details.rotation * 180 / 3.14159265358979,
      offset: _controller.offset + details.focalPointDelta,
    );
  }

  FaceOverlay _buildOverlay() {
    return switch (widget.overlayType) {
      CalibrationOverlayType.glasses => GlassesOverlay(
          image: widget.image,
          scaleMultiplier: _controller.scaleMultiplier,
          offset: _controller.offset,
          rotationOffset: _controller.rotationOffset,
        ),
      CalibrationOverlayType.sunglasses => SunglassesOverlay(
          image: widget.image,
          scaleMultiplier: _controller.scaleMultiplier,
          offset: _controller.offset,
          rotationOffset: _controller.rotationOffset,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                // Distinguishes this calibration surface from the
                // GestureDetectors Flutter builds internally for
                // SelectableText/buttons below — lets tests target it
                // precisely via find.byKey.
                key: const Key(
                    'flutter_virtual_tryon.calibrator.gestureSurface'),
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: VirtualTryOn(
                  backend: widget.backend,
                  cameraLens: widget.cameraLens,
                  overlays: [_buildOverlay()],
                ),
              ),
            ),
            _CalibrationPanel(controller: _controller, widget: widget),
          ],
        );
      },
    );
  }
}

class _CalibrationPanel extends StatelessWidget {
  const _CalibrationPanel({required this.controller, required this.widget});

  final CalibrationController controller;
  final OverlayCalibrator widget;

  @override
  Widget build(BuildContext context) {
    final code = controller.exportDartCode(
      imageExpression: widget.imageExpression,
      type: widget.overlayType,
    );
    return Material(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'scale ${controller.scaleMultiplier.toStringAsFixed(2)}  ·  '
              'offset (${controller.offset.dx.toStringAsFixed(1)}, '
              '${controller.offset.dy.toStringAsFixed(1)})  ·  '
              'rotation ${controller.rotationOffset.toStringAsFixed(1)}°',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: controller.reset,
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                  child: const Text('Copy code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
