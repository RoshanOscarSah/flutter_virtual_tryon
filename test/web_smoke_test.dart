// Web-only smoke test: forces the `dart.library.js_interop` branch of
// platform_backend.dart (media_pipe_backend.dart + web_bridge.dart) to
// actually compile for a browser target, which `flutter analyze`'s
// whole-program type checking doesn't fully exercise (JS interop has
// compile-time codegen concerns analysis alone can't catch). Run with:
//   flutter test --platform chrome test/web_smoke_test.dart
// Not part of the default `flutter test` run (VM target selects
// io_backend.dart instead), so CI's plain `flutter test` won't hit this
// file's import graph either — this is a manual/CI-web-lane check.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_virtual_tryon/flutter_virtual_tryon.dart';

void main() {
  test('VisionBackend.auto() constructs on web', () {
    final backend = VisionBackend.auto();
    expect(backend, isNotNull);
  });
}
