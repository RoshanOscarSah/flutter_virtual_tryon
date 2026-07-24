# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/), and this
project uses [Semantic Versioning](https://semver.org/) (see
[`doc/RELEASE.md`](doc/RELEASE.md)).

## Unreleased

## 0.3.0 - 2026-07-24

### Added

- **`VirtualTryOnImage(mirroredSource: true)`** — corrects a mirrored-source
  photo. A front-camera selfie saved with iOS's "Mirror Front Camera"
  setting reports its eyes on the sides opposite the unmirrored convention,
  so eyewear overlays render reversed/upside-down. Setting `mirroredSource`
  relabels the detected left/right landmarks so frames face the right way,
  without flipping the displayed photo. Defaults to false; there's no
  reliable metadata that says a photo was mirrored, so expose it as a
  user-facing "flip" toggle rather than guessing. The still-image analogue
  of the live iOS front-camera relabel.
- **`TrackingData.swapLeftRight()`** — returns a copy with the subject's
  left/right landmarks relabeled (eyes, irises, ears) while every coordinate
  stays put. Reverses the eye vector — and thus overlay rotation — without
  moving the overlay (`eyeCenter`/`eyeDistance` unchanged). Backs
  `mirroredSource` and is available for consumers doing custom still
  handling.

## 0.2.0 - 2026-07-23

### Added

- **`VirtualTryOnImage`** — still-photo try-on. Detects a face once in a
  supplied photo and paints the same `FaceOverlay`s over it, for a gallery
  pick or captured image rather than the live camera. Takes the encoded
  photo as a `Uint8List` (`image_picker`/`File.readAsBytes`/`rootBundle.load`
  all return this — detection needs the encoded bytes), sizes itself to the
  photo's aspect ratio, and offers `loadingBuilder`/`noFaceBuilder` slots
  plus `onFaceDetected`/`onError`. Shares the exact overlay paint pipeline
  with the live `VirtualTryOn` (see doc/DECISIONS.md #036).
  `MockVisionBackend(stillResult: ...)` drives it in tests. The detection
  engine already supported stills on every backend (`detectStill`); this
  exposes it publicly.
- Example: a "Photo Try-On" demo (`example/lib/demos/photo_demo.dart`) that
  gallery-picks an image (`image_picker`, example-only dep) and runs
  `VirtualTryOnImage`.

Additive only — no changes to existing public API. Internally, the overlay
`CustomPainter`s were extracted to a shared `renderer/overlays_painter.dart`
so both widgets use one pipeline (no behavior change).

## 0.1.3 - 2026-07-23

### Fixed

- **Live face tracking was broken on the iOS front camera** — two
  compounding coordinate bugs, both confirmed and fixed on a real device
  via `debugMode`:
  1. *Landmarks rotated ~90°* (eyes/nose/chin stacked into a vertical
     line). The ML Kit conversion ran iOS detections through the
     raw-sensor→upright rotation (`mlKitUprightPoint`), but on iOS the
     `camera` plugin already delivers a display-oriented buffer, so ML Kit
     returns coordinates *already upright* — rotating them again turned a
     level face 90°. Per Google's own `coordinates_translator.dart`, iOS
     points normalize directly against the raw image dimensions with no
     rotation; Android points need the rotation. The live path now
     branches on platform.
  2. *Eye-anchored overlays rendered upside down (180°)* once the rotation
     was fixed. The iOS front-camera buffer is mirrored, so ML Kit reports
     the subject's left eye at a smaller x than their right — the reverse
     of `TrackingData`'s unmirrored, subject-relative convention
     (doc/DECISIONS.md #015) — which flipped the eye vector and rotated
     glasses 180°. The iOS front-camera path now *relabels* ML Kit's
     left/right landmarks (new `swapLeftRight` option on the internal
     conversion) rather than flipping coordinates: the renderer keeps the
     preview and overlay in one shared raw-buffer space and mirrors both
     together, so flipping the overlay's coordinates would shift it
     sideways off the face — whereas a relabel corrects the eye vector's
     direction (fixing rotation) while leaving the eye midpoint, and thus
     the overlay's position, exactly where it belongs.

  Regression tests cover both: a level iOS face stays level (eyes share a
  `y`, differ in `x`), and `swapLeftRight` restores subject-left-on-right
  ordering with the eye midpoint unchanged. No public API changes —
  internal backend fixes.

  (Supersedes the 0.1.2 attempt, which changed the *rotation metadata*
  computation — the wrong layer. That change was a no-op in portrait,
  which is exactly why the reported portrait misalignment persisted.
  0.1.3 reverts the iOS rotation-metadata computation to Google's recipe
  and fixes the actual coordinate-space bug.)

## 0.1.2 - 2026-07-23

### Fixed

- Attempted fix for iOS live-tracking rotation by combining
  `sensorOrientation` with the device's current orientation on iOS.
  **Ineffective** — see 0.1.3, which identifies and fixes the real cause
  (the coordinate-space transform, not the rotation metadata). Kept in the
  history for the record; upgrade straight to 0.1.3.

## 0.1.1 - 2026-07-23

### Changed

- Raised the `camera` dependency floor from `^0.11.1` to `^0.12.0` and
  `google_mlkit_face_detection` from `^0.13.2` to `^0.14.0`, closing the
  gap to their latest stable releases (pub.dev's "up-to-date dependencies"
  score). Neither bump changes any public Dart API this package uses —
  `camera` 0.12.0's only relevant change is a dispose-safety bugfix;
  `google_mlkit_face_detection` 0.14.0 and its `google_mlkit_commons`
  0.12.0 dependency are native-implementation rewrites (Java→Kotlin,
  Objective-C→Swift) with no listed Dart-level signature changes.
  Verified via `flutter analyze` and the full test suite (132 tests) on
  both the package and example — live-camera behavior on a real
  Android/iOS device has not been separately re-verified against the new
  versions; flag this milestone's finding if `google_mlkit_commons`'s
  "enhanced image format validation" turns out to reject frames it
  previously accepted.

## 0.1.0 - 2026-07-23

### Added

- Project scaffold: package structure, analysis options, CI, and
  open-source standard files (LICENSE, CONTRIBUTING, CODE_OF_CONDUCT,
  SECURITY, issue/PR templates). No public API yet — see
  [`doc/ROADMAP.md`](doc/ROADMAP.md) milestone M1.
- Public API surface (milestone M1): `VirtualTryOn` widget +
  `VirtualTryOnController`, `VisionBackend.auto()`, overlay system
  (`FaceOverlay`, Glasses/Sunglasses/ContactLens/Custom), `TrackingData`,
  `OverlayConstraints`, `DebugOptions`, sealed `FaceLossBehavior`,
  `TryOnCapture`, `VirtualTryOnException`, and
  `package:flutter_virtual_tryon/testing.dart` with `MockVisionBackend`.
  Fully documented and frozen per doc/API.md's M1 addendum. Backends are
  placeholders until M2 — `VisionBackend.auto()` reports
  `backendUnavailable` everywhere for now.
- Real vision backends (milestone M2): `VisionBackend.auto()` now drives
  actual camera + detection instead of a placeholder. ML Kit on
  Android/iOS (live camera stream + still-image detection, ported
  rotation-compensation math); MediaPipe Face Landmarker on web (via a
  runtime-injected JS bridge — no `index.html` edit required, see
  doc/DECISIONS.md #021 — periodic-capture "live" tracking). macOS,
  Windows, and Linux report `backendUnavailable`: no auto-detection
  backend exists on desktop yet (doc/DECISIONS.md #020). All
  landmark-to-`TrackingData` conversion math is pure and unit-tested
  with fixtures (no camera/browser dependency); the web JS interop is
  additionally compile-checked against a real Chrome target in CI.
  SDK floor raised to Dart 3.3 / Flutter 3.19 for JS interop extension
  types (doc/DECISIONS.md #023). No public API changes.
- Real renderer (milestone M3): `VirtualTryOn` now shows a live
  `CameraPreview` instead of a placeholder, and `GlassesOverlay`/
  `SunglassesOverlay` actually paint their resolved image at the correct
  eye-anchored position, size, and rotation — computed in pixel space
  (not the normalized-space approximation `TrackingData.rotationRadians`
  would give on a non-square view; see doc/DECISIONS.md #026/#027) via a
  new `OverlayImageResolver` that caches resolved images per
  `VirtualTryOn` instance. Smoothing engine implemented
  (`smoothTracking`, exponential moving average, resets across face-loss
  gaps). Mirroring is now applied once at the widget level so the camera
  image and overlays can't drift out of sync. Verified with a genuine
  pixel-level render test (no golden-file dependency). No public API
  changes beyond two additive fields on `FaceOverlayPaintContext`
  (`images`, `imageConfiguration`) — internal-use, not yet part of the
  documented API surface (doc/DECISIONS.md #024).
- `ContactLensOverlay` implementation (milestone M4): paints per-eye,
  anchored on iris landmarks when the backend provides them (MediaPipe)
  and automatically falling back to eye centers otherwise (ML Kit) —
  size still tracks the whole eye pair, not just one landmark, so it
  doesn't jitter independently per eye (doc/DECISIONS.md #028).
- Debug overlay implementation (milestone M4): every `DebugOptions`
  visualization now actually draws — face box, landmarks, eye centers,
  anchors, and a text panel (FPS/rotation/scale/confidence). Rendered
  inside the same mirror transform as the camera preview and overlays so
  position markers stay aligned with what's on screen
  (doc/DECISIONS.md #029).
- `TrackingData.fps`/`timestamp` (declared in M1, unused until now) are
  populated by both backends per live frame — a real per-backend
  frame-rate measurement, not a dead field (doc/DECISIONS.md #030).
- `VirtualTryOnController.capture()` implemented (milestone M4): snapshots
  the composited frame (camera + overlays + debug overlay) as a PNG via
  a `RepaintBoundary`, delivered to both the return value and
  `VirtualTryOn.onCapture`. Returns null on any failure, fulfilling the
  contract documented since M1 (doc/DECISIONS.md #031).
- No public API changes beyond what M3 already added
  (`FaceOverlayPaintContext.images`/`imageConfiguration`) — M4 is
  implementation-only against the frozen surface.
- Calibration mode (milestone M5): new `CalibrationController` (a plain
  `ChangeNotifier` holding `scaleMultiplier`/`offset`/`rotationOffset`)
  and `OverlayCalibrator` widget — wrap it around a `GlassesOverlay`/
  `SunglassesOverlay` image, drag/pinch/twist to tune placement live
  against a real camera preview, and copy a ready-to-paste
  `GlassesOverlay(...)`/`SunglassesOverlay(...)` Dart snippet from the
  on-screen export panel (doc/DECISIONS.md #032). Both exported publicly
  from the package barrel.
- Example app expansion (milestone M5): `example/` grew from a single
  placeholder screen into 5 runnable demos reachable from a menu —
  quick-start, optical shop (multi-product picker), custom overlay
  (star-above-eyes via `CustomOverlay`), debug mode (all `DebugOptions`
  toggles live), and calibration. Demo artwork is generated at runtime
  rather than bundled or linked (doc/DECISIONS.md #033). iOS and Android
  camera permissions added to the example project; macOS deliberately
  excluded since it has no auto-detection backend (doc/DECISIONS.md
  #020, #034). Verified running live in Chrome (web), not just via
  `flutter analyze`/`flutter test`.
- No public API changes beyond the two new calibration types
  (`CalibrationController`, `OverlayCalibrator`) — purely additive.
- Documentation and test coverage pass (milestone M6): README rewritten
  from its pre-implementation skeleton into a real reference — installation,
  a working quick-start, every built-in overlay, calibration mode, debug
  mode, testing with `MockVisionBackend`, and a troubleshooting section
  covering the ML Kit arm64-simulator linking issue, camera permissions,
  and macOS's expected `backendUnavailable` state. Test suite grew from 109
  to 132 tests, raising overall line coverage from 77.0% to 83.4%; every
  source file is now at 100% coverage except three that talk to real
  camera/ML Kit hardware, which stay manually (not unit) tested per
  doc/TESTING.md's "never depend on a real camera" rule — see that
  document's "Current Coverage" section for the full breakdown.
- No public API changes — M6 is documentation and tests only.
