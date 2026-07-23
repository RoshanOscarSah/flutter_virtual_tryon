/// Test utilities for apps using flutter_virtual_tryon.
///
/// Import in tests only:
///
/// ```dart
/// import 'package:flutter_virtual_tryon/testing.dart';
/// ```
///
/// [MockVisionBackend] drives a `VirtualTryOn` widget with scripted
/// tracking data — no camera, no ML models — so widget tests can exercise
/// detection, loss, and error flows deterministically.
library;

export 'src/testing/mock_vision_backend.dart';
