import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_virtual_tryon_example/main.dart';

void main() {
  testWidgets('ExampleApp builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('the demo menu lists every demo', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Quick Start'), findsOneWidget);
    expect(find.text('Optical Shop'), findsOneWidget);
    expect(find.text('Custom Overlay'), findsOneWidget);
    expect(find.text('Debug Mode'), findsOneWidget);
    expect(find.text('Calibration'), findsOneWidget);
  });

  testWidgets('tapping a demo navigates to its screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Custom Overlay'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Custom Overlay'), findsOneWidget);
  });
}
