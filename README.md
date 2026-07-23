# flutter_virtual_tryon

A cross-platform face tracking and overlay engine for Flutter. It hides
computer-vision complexity behind a stable, intuitive API so any Flutter
developer can add professional face-tracking overlays — glasses,
sunglasses, contact lenses, and custom overlays — in minutes.

This is **not** a glasses package. Glasses are one built-in overlay on top
of a generic tracking + rendering engine. See
[`doc/VISION.md`](doc/VISION.md) for the long-term goal and
[`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md) for how it's built.

> **Status:** feature-complete for 0.1.0 (milestones M0–M5) and not yet
> published to pub.dev. Everything below — the API, the examples, the
> platform notes — describes what's actually implemented and tested
> today; see [`doc/ROADMAP.md`](doc/ROADMAP.md) for what's still ahead
> before release.

## Supported platforms

| Platform | Status |
| -------- | ------ |
| Android  | ML Kit backend, live camera |
| iOS      | ML Kit backend, live camera |
| Web      | MediaPipe backend, live camera |
| macOS    | No auto-detection backend — `VisionBackend.auto()` reports `backendUnavailable`; the widget still renders overlays if you drive them manually (e.g. via [`OverlayCalibrator`](#calibration-mode)). See [`doc/DECISIONS.md`](doc/DECISIONS.md) #020. |

## Installation

Not yet published to pub.dev. Until then, depend on it as a path or git
dependency:

```yaml
dependencies:
  flutter_virtual_tryon:
    path: ../flutter_virtual_tryon # or a git: entry pointing at this repo
```

Once published, installation will be the standard:

```bash
flutter pub add flutter_virtual_tryon
```

## Quick start

```dart
VirtualTryOn(
  backend: VisionBackend.auto(),
  overlays: [
    GlassesOverlay(image: AssetImage('assets/rayban.png')),
  ],
)
```

That's the whole package for the common case: `VisionBackend.auto()`
picks ML Kit on Android/iOS or MediaPipe on web, opens the camera, tracks
the face, and paints the overlay eye-anchored and rotation/scale-aware
every frame. See [`example/lib/demos/quick_start_demo.dart`](example/lib/demos/quick_start_demo.dart)
for a runnable version.

### Handling errors and face loss

```dart
VirtualTryOn(
  overlays: [GlassesOverlay(image: AssetImage('assets/rayban.png'))],
  faceLossBehavior: FaceLossBehavior.fade(),
  onError: (error) {
    // error.code is a VirtualTryOnErrorCode you can switch on:
    // backendUnavailable, cameraPermissionDenied, cameraUnavailable,
    // captureFailed, backendFailure.
    debugPrint(error.message);
  },
)
```

### Capturing a photo

```dart
final controller = VirtualTryOnController();

VirtualTryOn(controller: controller, overlays: [...]);

// Later, e.g. on a button press:
final shot = await controller.capture(); // TryOnCapture? — PNG + dimensions
```

## Photo / still-image try-on

Try frames on a **static photo** (a gallery pick or captured image) instead
of the live camera with `VirtualTryOnImage`:

```dart
VirtualTryOnImage(
  imageBytes: await pickedFile.readAsBytes(), // Uint8List of the encoded photo
  overlays: [GlassesOverlay(image: AssetImage('assets/rayban.png'))],
  noFaceBuilder: (context) => const Text('No face found — try another photo'),
)
```

It detects a face once, then paints the same overlays over the photo. Takes
the **encoded bytes** (`Uint8List` — what `image_picker`/`File.readAsBytes`/
`rootBundle.load` give you) because face detection needs them, and sizes
itself to the photo's aspect ratio (place it in an `Expanded`/`Center`/sized
box). `mirror` defaults to `false` since a saved photo isn't selfie-mirrored.
See [`example/lib/demos/photo_demo.dart`](example/lib/demos/photo_demo.dart).

## Built-in overlays

- **`GlassesOverlay`** / **`SunglassesOverlay`** — an `ImageProvider`
  anchored on the eyes, with `scaleMultiplier`, `offset`, and
  `rotationOffset` for fine-tuning.
- **`ContactLensOverlay`** — per-eye iris textures. Anchors on iris
  landmarks when the backend provides them (MediaPipe/web) and falls back
  to eye centers automatically otherwise (ML Kit/Android/iOS) — see
  [`doc/DECISIONS.md`](doc/DECISIONS.md) #028.
- **`CustomOverlay`** — the escape hatch: paint anything with plain
  `Canvas` calls, given the same `TrackingData` every built-in overlay
  uses. See [`example/lib/demos/custom_overlay_demo.dart`](example/lib/demos/custom_overlay_demo.dart).

Every overlay accepts `visibleWhen: OverlayConstraints(...)` to hide it
automatically outside a face-size, tilt, or confidence range — no manual
visibility logic needed.

## Calibration mode

`OverlayCalibrator` wraps a `VirtualTryOn` with drag/pinch/twist gestures
and a live export panel, so you can tune an overlay against your own face
and copy the result straight into your app instead of guessing at
numbers:

```dart
OverlayCalibrator(
  image: AssetImage('assets/rayban.png'),
  imageExpression: "AssetImage('assets/rayban.png')",
)
```

Drag to reposition, pinch to scale, twist to rotate. The panel below the
preview shows the live values and a ready-to-paste
`GlassesOverlay(...)` constructor call, plus Reset and Copy code buttons.
See [`example/lib/demos/calibration_demo.dart`](example/lib/demos/calibration_demo.dart)
and [`doc/DECISIONS.md`](doc/DECISIONS.md) #032.

## Debug mode

```dart
VirtualTryOn(
  debugMode: true,
  debugOptions: DebugOptions(
    showFPS: true,
    showFaceBox: true,
    showLandmarks: true,
    showEyeCenters: true,
    showAnchors: true,
    showRotation: true,
    showScale: true,
    showTrackingConfidence: true,
  ),
  overlays: [...],
)
```

Draws every tracked landmark, the face bounding box, and a text panel
(FPS/rotation/scale/confidence) directly over the preview — invaluable
while integrating a new overlay. See
[`example/lib/demos/debug_mode_demo.dart`](example/lib/demos/debug_mode_demo.dart).

## Testing your own app

`package:flutter_virtual_tryon/testing.dart` exports `MockVisionBackend`,
a scriptable backend for widget tests — no camera or ML models required:

```dart
import 'package:flutter_virtual_tryon/testing.dart';

final backend = MockVisionBackend();
await tester.pumpWidget(VirtualTryOn(backend: backend, overlays: [...]));
backend.emit(someTrackingData); // -> onFaceDetected / onFaceUpdated
backend.emit(null);             // -> onFaceLost
```

The package's own test suite uses the same tool — see
[`doc/TESTING.md`](doc/TESTING.md) for the full strategy and current
coverage.

## Examples

[`example/`](example/) is a menu of five runnable demos, each showing a
different facet of the package:

| Demo | What it shows |
| ---- | -------------- |
| Quick Start | The whole package in a few lines |
| Optical Shop | Product grid + live try-on, switching frames — the primary target use case |
| Custom Overlay | `CustomOverlay` drawing with plain `Canvas` calls |
| Debug Mode | Every `DebugOptions` visualization, toggleable live |
| Calibration | `OverlayCalibrator` — tune placement live, export ready-to-paste code |

```bash
cd example
flutter run
```

## Troubleshooting

**iOS Simulator: "Building for iOS-simulator, but linking in object file
built for iOS"** — `google_mlkit_face_detection`'s vendored pods don't
ship arm64-simulator slices, which breaks on Apple-silicon Macs (their
simulators are arm64-only). Add an `EXCLUDED_ARCHS[sdk=iphonesimulator*]`
override and a strip-and-relink step to your `ios/Podfile`'s
`post_install` — see [`example/ios/Podfile`](example/ios/Podfile) and
[`example/tool/strip_ios_device_platform.py`](example/tool/strip_ios_device_platform.py)
for the exact fix this package's own example app uses.

**Camera preview stays black / `onError` fires with
`cameraPermissionDenied` or `cameraUnavailable`** — declare camera usage
on each platform: `NSCameraUsageDescription` in `ios/Runner/Info.plist`,
and `android.permission.CAMERA` (plus the `android.hardware.camera`
feature) in `AndroidManifest.xml`. See
[`example/ios/Runner/Info.plist`](example/ios/Runner/Info.plist) and
[`example/android/app/src/main/AndroidManifest.xml`](example/android/app/src/main/AndroidManifest.xml).

**`onError` fires with `backendUnavailable` on macOS** — expected, not a
bug: there's no auto-detection backend on desktop in 0.1.0 (see the
platform table above). The widget still renders; drive overlays manually
(e.g. `OverlayCalibrator`) instead of relying on live tracking.

**Overlay looks slightly off** — use [Calibration mode](#calibration-mode)
rather than guessing at `scaleMultiplier`/`offset`/`rotationOffset`, or
turn on [Debug mode](#debug-mode) to see exactly where the engine thinks
the landmarks are.

## Documentation

- [Vision](doc/VISION.md) — mission and long-term goals
- [Architecture](doc/ARCHITECTURE.md) — module layout and design principles
- [Public API](doc/API.md) — the frozen API surface
- [Decisions](doc/DECISIONS.md) — why things are built the way they are
- [Roadmap](doc/ROADMAP.md) — development phases
- [Testing](doc/TESTING.md) — testing strategy and current coverage
- [Release process](doc/RELEASE.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please read
[`doc/CODING_STANDARDS.md`](doc/CODING_STANDARDS.md) and
[`doc/DECISIONS.md`](doc/DECISIONS.md) before proposing changes — this
package is designed to be a long-term production dependency, and public API
stability is treated as a feature.

## License

MIT — see [LICENSE](LICENSE).
