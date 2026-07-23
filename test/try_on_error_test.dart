import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

void main() {
  group('VirtualTryOnException', () {
    test('toString includes the code and message', () {
      const error = VirtualTryOnException(
        VirtualTryOnErrorCode.cameraUnavailable,
        'No camera found',
      );
      expect(
        error.toString(),
        'VirtualTryOnException(cameraUnavailable): No camera found',
      );
    });

    test('toString appends the cause when present', () {
      final error = VirtualTryOnException(
        VirtualTryOnErrorCode.backendFailure,
        'Detector crashed',
        'native error',
      );
      expect(
        error.toString(),
        'VirtualTryOnException(backendFailure): Detector crashed '
        '(cause: native error)',
      );
    });

    test('exposes code, message, and cause', () {
      final cause = Exception('boom');
      final error = VirtualTryOnException(
        VirtualTryOnErrorCode.captureFailed,
        'capture() failed',
        cause,
      );
      expect(error.code, VirtualTryOnErrorCode.captureFailed);
      expect(error.message, 'capture() failed');
      expect(error.cause, cause);
    });
  });
}
