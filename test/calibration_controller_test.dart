import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/src/calibration/calibration_controller.dart';

void main() {
  group('CalibrationController defaults', () {
    test('starts at identity values by default', () {
      final controller = CalibrationController();
      expect(controller.scaleMultiplier, 1.0);
      expect(controller.offset, Offset.zero);
      expect(controller.rotationOffset, 0.0);
    });

    test('starts at the given initial values', () {
      final controller = CalibrationController(
        initialScaleMultiplier: 1.08,
        initialOffset: const Offset(4, -3),
        initialRotationOffset: 1.5,
      );
      expect(controller.scaleMultiplier, 1.08);
      expect(controller.offset, const Offset(4, -3));
      expect(controller.rotationOffset, 1.5);
    });
  });

  group('CalibrationController.update', () {
    test('updates only the fields passed', () {
      final controller = CalibrationController();
      controller.update(scaleMultiplier: 1.5);
      expect(controller.scaleMultiplier, 1.5);
      expect(controller.offset, Offset.zero);
      expect(controller.rotationOffset, 0.0);

      controller.update(offset: const Offset(2, 3));
      expect(controller.scaleMultiplier, 1.5); // unchanged
      expect(controller.offset, const Offset(2, 3));

      controller.update(rotationOffset: 10);
      expect(controller.rotationOffset, 10);
      expect(controller.scaleMultiplier, 1.5); // still unchanged
    });

    test('clamps scaleMultiplier to stay positive', () {
      final controller = CalibrationController();
      controller.update(scaleMultiplier: -5);
      expect(controller.scaleMultiplier, greaterThan(0));
      controller.update(scaleMultiplier: 0);
      expect(controller.scaleMultiplier, greaterThan(0));
    });

    test('notifies listeners when a value actually changes', () {
      final controller = CalibrationController();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.update(scaleMultiplier: 1.2);
      expect(notified, 1);
    });

    test('does not notify listeners when nothing changes', () {
      final controller = CalibrationController(initialScaleMultiplier: 1.2);
      var notified = 0;
      controller.addListener(() => notified++);
      controller.update(scaleMultiplier: 1.2); // same value
      expect(notified, 0);
    });
  });

  group('CalibrationController.reset', () {
    test('restores the constructed initial values', () {
      final controller = CalibrationController(
        initialScaleMultiplier: 1.08,
        initialOffset: const Offset(4, -3),
        initialRotationOffset: 1.5,
      );
      controller.update(
        scaleMultiplier: 2.0,
        offset: const Offset(99, 99),
        rotationOffset: 45,
      );
      controller.reset();
      expect(controller.scaleMultiplier, 1.08);
      expect(controller.offset, const Offset(4, -3));
      expect(controller.rotationOffset, 1.5);
    });
  });

  group('CalibrationController.exportDartCode', () {
    test('formats a GlassesOverlay constructor call by default', () {
      final controller = CalibrationController(
        initialScaleMultiplier: 1.08,
        initialOffset: const Offset(4, -3),
        initialRotationOffset: 1.5,
      );
      final code = controller.exportDartCode(
        imageExpression: "AssetImage('assets/rayban.png')",
      );
      expect(code, '''
GlassesOverlay(
  image: AssetImage('assets/rayban.png'),
  scaleMultiplier: 1.08,
  offset: Offset(4.00, -3.00),
  rotationOffset: 1.50,
)''');
    });

    test('formats a SunglassesOverlay constructor call when requested', () {
      final controller = CalibrationController();
      final code = controller.exportDartCode(
        imageExpression: "AssetImage('a.png')",
        type: CalibrationOverlayType.sunglasses,
      );
      expect(code, startsWith('SunglassesOverlay('));
    });

    test('rounds to 2 decimal places', () {
      final controller = CalibrationController(
        initialScaleMultiplier: 1.0834729,
      );
      final code = controller.exportDartCode(imageExpression: 'x');
      expect(code, contains('scaleMultiplier: 1.08,'));
    });
  });
}
