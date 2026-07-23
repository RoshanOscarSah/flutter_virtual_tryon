import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/testing.dart';

// A 1x1 transparent GIF — tiny, valid, and decodable, but its actual pixel
// content is irrelevant: these tests check gesture/controller/export
// behavior, never rendered pixels, so nothing here needs runAsync (no
// paint() call is awaited or inspected).
final _placeholderImage = MemoryImage(
  Uint8List.fromList([
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, //
    0x80, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x21,
    0xF9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44,
    0x01, 0x00, 0x3B,
  ]),
);

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  testWidgets('renders the VirtualTryOn preview and export panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          height: 500,
          child: OverlayCalibrator(
            image: _placeholderImage,
            imageExpression: "AssetImage('a.png')",
            backend: MockVisionBackend(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(VirtualTryOn), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);
  });

  testWidgets('exported code reflects the default identity values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          height: 500,
          child: OverlayCalibrator(
            image: _placeholderImage,
            imageExpression: "AssetImage('a.png')",
            backend: MockVisionBackend(),
          ),
        ),
      ),
    );
    await tester.pump();
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, contains('scaleMultiplier: 1.00'));
    expect(text.data, contains('offset: Offset(0.00, 0.00)'));
    expect(text.data, contains('rotationOffset: 0.00'));
  });

  testWidgets('a drag gesture updates the offset and the export panel', (
    tester,
  ) async {
    final controller = CalibrationController();
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          height: 500,
          child: OverlayCalibrator(
            image: _placeholderImage,
            imageExpression: "AssetImage('a.png')",
            backend: MockVisionBackend(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
        find.byKey(
            const Key('flutter_virtual_tryon.calibrator.gestureSurface')),
        const Offset(20, 10));
    await tester.pump();

    expect(controller.offset.dx, closeTo(20, 0.5));
    expect(controller.offset.dy, closeTo(10, 0.5));
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, contains('offset: Offset(20.00, 10.00)'));
  });

  testWidgets('Reset restores the initial values after a gesture', (
    tester,
  ) async {
    final controller = CalibrationController(initialScaleMultiplier: 1.1);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          height: 500,
          child: OverlayCalibrator(
            image: _placeholderImage,
            imageExpression: "AssetImage('a.png')",
            backend: MockVisionBackend(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
        find.byKey(
            const Key('flutter_virtual_tryon.calibrator.gestureSurface')),
        const Offset(50, 0));
    await tester.pump();
    expect(controller.offset, isNot(Offset.zero));

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(controller.offset, Offset.zero);
    expect(controller.scaleMultiplier, 1.1);
  });

  testWidgets('Copy code writes the export text to the clipboard', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          height: 500,
          child: OverlayCalibrator(
            image: _placeholderImage,
            imageExpression: "AssetImage('rayban.png')",
            backend: MockVisionBackend(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Copy code'));
    await tester.pump();

    expect(copied, hasLength(1));
    expect(copied.single, contains("AssetImage('rayban.png')"));
    expect(copied.single, startsWith('GlassesOverlay('));
  });

  testWidgets('overlayType: sunglasses exports a SunglassesOverlay call', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          height: 500,
          child: OverlayCalibrator(
            image: _placeholderImage,
            imageExpression: "AssetImage('a.png')",
            overlayType: CalibrationOverlayType.sunglasses,
            backend: MockVisionBackend(),
          ),
        ),
      ),
    );
    await tester.pump();
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, startsWith('SunglassesOverlay('));
  });
}
