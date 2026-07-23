import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;

/// Which built-in overlay type [CalibrationController.exportDartCode]
/// formats its output as.
enum CalibrationOverlayType {
  /// Export a `GlassesOverlay(...)` constructor call.
  glasses,

  /// Export a `SunglassesOverlay(...)` constructor call.
  sunglasses,
}

/// Live-adjustable placement values for an eye-anchored overlay
/// (`GlassesOverlay`/`SunglassesOverlay`), tuned interactively via
/// [OverlayCalibrator] and exportable as a ready-to-paste Dart snippet
/// (doc/PRODUCT_REQUIREMENTS.md's "Calibration Mode").
///
/// This is a plain [ChangeNotifier] holding the three values every
/// eye-anchored overlay already exposes — [scaleMultiplier], [offset],
/// [rotationOffset] — so it has no gesture-handling logic of its own;
/// [OverlayCalibrator] computes deltas from Flutter's gesture callbacks
/// and calls [update] with the resulting absolute values. Kept separate
/// so calibration math is testable without a widget tree.
class CalibrationController extends ChangeNotifier {
  /// Creates a controller starting from [initialScaleMultiplier],
  /// [initialOffset], and [initialRotationOffset] — typically values
  /// already found via a previous calibration session, so tuning resumes
  /// where it left off instead of starting from scratch.
  CalibrationController({
    double initialScaleMultiplier = 1.0,
    Offset initialOffset = Offset.zero,
    double initialRotationOffset = 0.0,
  })  : _scaleMultiplier = initialScaleMultiplier,
        _offset = initialOffset,
        _rotationOffset = initialRotationOffset,
        _resetScaleMultiplier = initialScaleMultiplier,
        _resetOffset = initialOffset,
        _resetRotationOffset = initialRotationOffset;

  double _scaleMultiplier;
  Offset _offset;
  double _rotationOffset;

  final double _resetScaleMultiplier;
  final Offset _resetOffset;
  final double _resetRotationOffset;

  /// Current value for `GlassesOverlay.scaleMultiplier`.
  double get scaleMultiplier => _scaleMultiplier;

  /// Current value for `GlassesOverlay.offset`.
  Offset get offset => _offset;

  /// Current value for `GlassesOverlay.rotationOffset`, in degrees.
  double get rotationOffset => _rotationOffset;

  /// Applies new absolute values, clamping [scaleMultiplier] to stay
  /// positive (a zero or negative scale would make the overlay
  /// disappear or flip, neither of which is a useful calibration state).
  /// Omitted parameters leave that value unchanged. Notifies listeners
  /// only if something actually changed.
  void update(
      {double? scaleMultiplier, Offset? offset, double? rotationOffset}) {
    final newScale = scaleMultiplier == null
        ? _scaleMultiplier
        : scaleMultiplier.clamp(0.05, double.infinity).toDouble();
    final newOffset = offset ?? _offset;
    final newRotation = rotationOffset ?? _rotationOffset;
    if (newScale == _scaleMultiplier &&
        newOffset == _offset &&
        newRotation == _rotationOffset) {
      return;
    }
    _scaleMultiplier = newScale;
    _offset = newOffset;
    _rotationOffset = newRotation;
    notifyListeners();
  }

  /// Restores the values the controller was constructed with.
  void reset() {
    update(
      scaleMultiplier: _resetScaleMultiplier,
      offset: _resetOffset,
      rotationOffset: _resetRotationOffset,
    );
  }

  /// Formats the current values as a ready-to-paste constructor call —
  /// see doc/PRODUCT_REQUIREMENTS.md's Calibration Mode example. Values
  /// are rounded to 2 decimal places, matching the precision that
  /// example shows and that's realistically distinguishable by eye.
  ///
  /// [imageExpression] is inserted verbatim as the `image:` argument —
  /// pass whatever `ImageProvider` expression the target code should use,
  /// e.g. `"AssetImage('assets/rayban.png')"`.
  String exportDartCode({
    required String imageExpression,
    CalibrationOverlayType type = CalibrationOverlayType.glasses,
  }) {
    final typeName = switch (type) {
      CalibrationOverlayType.glasses => 'GlassesOverlay',
      CalibrationOverlayType.sunglasses => 'SunglassesOverlay',
    };
    String fmt(double v) => v.toStringAsFixed(2);
    return '$typeName(\n'
        '  image: $imageExpression,\n'
        '  scaleMultiplier: ${fmt(_scaleMultiplier)},\n'
        '  offset: Offset(${fmt(_offset.dx)}, ${fmt(_offset.dy)}),\n'
        '  rotationOffset: ${fmt(_rotationOffset)},\n'
        ')';
  }
}
