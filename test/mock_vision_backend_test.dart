import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';
import 'package:flutter_virtual_tryon/testing.dart';

void main() {
  group('MockVisionBackend.detectStill', () {
    test('resolves to the configured stillResult', () async {
      const data = TrackingData(
        boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
        leftEye: Offset(0.6, 0.4),
        rightEye: Offset(0.4, 0.4),
        confidence: 1.0,
      );
      final backend = MockVisionBackend(stillResult: data);
      expect(await backend.detectStill(Uint8List(0)), same(data));
    });

    test('defaults to null (no face found)', () async {
      final backend = MockVisionBackend();
      expect(await backend.detectStill(Uint8List(0)), isNull);
    });

    test('stillResult is mutable between calls', () async {
      final backend = MockVisionBackend();
      expect(await backend.detectStill(Uint8List(0)), isNull);
      const data = TrackingData(
        boundingBox: Rect.fromLTWH(0.3, 0.25, 0.4, 0.5),
        leftEye: Offset(0.6, 0.4),
        rightEye: Offset(0.4, 0.4),
        confidence: 1.0,
      );
      backend.stillResult = data;
      expect(await backend.detectStill(Uint8List(0)), same(data));
    });
  });
}
