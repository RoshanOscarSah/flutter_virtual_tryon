# flutter_virtual_tryon Public API

This document defines the public API.

Public APIs should not change without careful consideration.

---

# Primary Widget

```dart
VirtualTryOn(
  backend: VisionBackend.auto(),

  cameraLens: CameraLens.front,

  mirror: true,

  smoothTracking: true,

  performanceMode: PerformanceMode.balanced,

  faceLossBehavior: FaceLossBehavior.hide,

  debugMode: false,

  debugOptions: DebugOptions(),

  overlays: [],

  onInitialized: () {},

  onFaceDetected: (face) {},

  onFaceUpdated: (tracking) {},

  onFaceLost: () {},

  onCapture: (image) {},

  onError: (error) {},
)
```

---

# Built-in Overlays

## GlassesOverlay

Supports:

- ImageProvider
- Scale multiplier
- Offset
- Rotation offset
- Overlay constraints

---

## SunglassesOverlay

Same API as GlassesOverlay.

---

## ContactLensOverlay

Supports:

- Left eye texture
- Right eye texture
- Iris scaling
- Opacity
- Automatic fallback

---

## CustomOverlay

Allows developers to create custom overlay behavior.

---

# TrackingData

Expose:

- Face center
- Bounding box
- Translation
- Rotation
- Scale
- Confidence
- FPS
- Face width
- Face height
- Left eye
- Right eye
- Left iris
- Right iris
- Nose
- Chin
- Forehead
- Left ear
- Right ear

---

# DebugOptions

Supports:

- showFPS
- showFaceBox
- showLandmarks
- showEyeCenters
- showAnchors
- showRotation
- showScale
- showTrackingConfidence

---

# OverlayConstraints

Supports:

- Minimum face size
- Maximum face size
- Maximum head tilt
- Minimum confidence
- Require both eyes
- Require iris detection

---

# Performance Modes

- Fast
- Balanced
- HighAccuracy

---

# Face Loss Behavior

- Hide
- Freeze
- Fade
- Callback

---

# Vision Backend

Public API

```dart
VisionBackend.auto()
```

The underlying implementation is intentionally hidden.

---

# Public API Rules

1. Never expose ML Kit classes.
2. Never expose MediaPipe classes.
3. Never expose Apple Vision classes.
4. Prefer additive changes over breaking changes.
5. Mark experimental APIs clearly.
6. Every public API must be documented.
7. Every public API must have tests.

---

# API Freeze Addendum (M1, 2026-07-20)

The surface above is now implemented and frozen. The following conventions
and additions were fixed during implementation and are part of the contract.

## Conventions

- **Coordinates are normalized**: `(0,0)` = frame top-left, `(1,1)` =
  bottom-right, y-down. Multiply by a render box's size for pixels.
- **Coordinates are unmirrored**; the renderer applies selfie mirroring.
- **Left/right are the subject's own** (subject's left eye appears on the
  frame's right in an unmirrored image) — matches ML Kit and MediaPipe.
- **Rotation is in degrees**, 0 = level, positive = clockwise on screen
  (subject's left eye lower). `rotationRadians` is provided for
  `Transform.rotate`.
- `TrackingData` exists **only while a face is tracked** — it carries no
  state field. `TrackingState` lives on `VirtualTryOnController`.
- `OverlayConstraints.minFaceSize`/`maxFaceSize` are in logical pixels of
  the rendered view; evaluation happens at paint time via
  `isSatisfiedBy(data, viewSize: ...)`.

## Additions

- **`VirtualTryOnController`** — `capture()`, `trackingState`,
  `lastTrackingData`. Fills the gap of what *triggers* `onCapture`
  (standard Flutter controller pattern). Optional `controller` param on
  the widget.
- **`TryOnCapture`** — PNG bytes + dimensions, returned by `capture()`.
- **`VirtualTryOnException` / `VirtualTryOnErrorCode`** — the typed error
  delivered to `onError`.
- **`FaceLossBehavior` is a sealed class**, not an enum:
  `hide()` / `freeze()` / `fade(duration:)` / `custom()`. Fade needs a
  duration, and sealed switches stay exhaustive. `onFaceLost` always
  fires regardless of variant; `custom()` = no built-in visual action.
- **`backend` is optional**, defaulting to `VisionBackend.auto()`.
- **`FaceOverlayPaintContext`** — the single argument to
  `FaceOverlay.paint`; new capabilities become new fields (non-breaking).
- **`package:flutter_virtual_tryon/testing.dart`** — exports
  `MockVisionBackend` so apps can widget-test try-on flows with no
  camera. Part of the supported public surface.

---

# Still-image try-on (0.2.0)

```dart
VirtualTryOnImage(
  imageBytes: photoBytes,          // required Uint8List (encoded JPEG/PNG)

  overlays: [
    GlassesOverlay(image: AssetImage('assets/rayban.png')),
  ],

  backend: VisionBackend.auto(),   // optional; same backends as VirtualTryOn
  mirror: false,                   // optional; flips the displayed photo
  mirroredSource: false,           // optional; corrects a mirrored selfie

  loadingBuilder: (context) {},    // optional; while detection runs
  noFaceBuilder: (context) {},     // optional; when no face is found
  onFaceDetected: (tracking) {},   // optional
  onError: (error) {},             // optional
)
```

The still-photo sibling of `VirtualTryOn`. Detects a face **once** in the
supplied photo and paints the same `FaceOverlay`s over it, for a gallery
pick or a captured image rather than a live camera.

- **`imageBytes` is a `Uint8List`** of the *encoded* photo (JPEG/PNG) —
  what `image_picker`, `File.readAsBytes`, and `rootBundle.load` return.
  Encoded bytes rather than an `ImageProvider` because detection needs
  them (ML Kit reads a file, MediaPipe a blob). Convenience
  `ImageProvider`-based constructors may be added later without a breaking
  change.
- **Sizes itself to the photo.** The image and overlays render inside an
  `AspectRatio` locked to the photo's own dimensions; place the widget in a
  bounded box (`Expanded`, `Center`, a sized parent) like any
  `AspectRatio`.
- **`mirror` defaults to `false`** (a saved photo isn't mirrored like a
  live selfie preview). `mirror` flips the *displayed* photo and overlays.
- **`mirroredSource` defaults to `false`.** Set it true when the photo was
  captured mirrored — most often a front-camera selfie (iOS's "Mirror Front
  Camera"). Such a photo reports its eyes on the opposite sides, so eyewear
  would render reversed/upside-down. `mirroredSource` relabels the detected
  left/right landmarks (`TrackingData.swapLeftRight`) so frames face the
  right way, **without** flipping the displayed photo — distinct from
  `mirror`. There's no reliable "was this mirrored?" signal, so surface it as
  a user-facing flip toggle; toggling repaints instantly (no re-detection).
- Same `VisionBackend` / `VisionBackendException` / `TrackingData` types as
  the live widget; `MockVisionBackend(stillResult: ...)` drives it in tests.

`TrackingData.swapLeftRight()` is public for consumers doing their own still
handling: it returns a copy with the subject's left/right landmarks (eyes,
irises, ears) relabeled while every coordinate stays put — reversing the eye
vector (and thus overlay rotation) without moving the overlay.
