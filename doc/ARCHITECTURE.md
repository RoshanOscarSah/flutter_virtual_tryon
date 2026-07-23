# flutter_virtual_tryon Architecture

## Purpose

`flutter_virtual_tryon` is a production-grade, cross-platform Flutter package that provides a face tracking and overlay engine for virtual try-on experiences.

The package hides computer vision complexity behind a stable and intuitive Flutter API.

It is **not** a glasses package.

It is a reusable engine that enables overlays such as:

- Glasses
- Sunglasses
- Contact Lenses
- Hats
- Earrings
- Masks
- Helmets
- Makeup
- Custom Overlays

---

# Design Principles

1. Public API comes first.
2. Public API must remain stable.
3. Implementation details must never leak into the public API.
4. Cross-platform consistency is mandatory.
5. Performance is a first-class feature.
6. Every component must be independently testable.
7. Favor composition over inheritance.
8. Backwards compatibility is more important than adding new features.

---

# Supported Platforms

| Platform | Status  |
| -------- | ------- |
| Android  | ✅      |
| iOS      | ✅      |
| Web      | ✅      |
| macOS    | ✅      |
| Windows  | Planned |
| Linux    | Planned |

---

# High-Level Architecture

Camera

↓

Vision Backend

↓

Face Detection

↓

Landmark Detection

↓

Tracking Engine

↓

Smoothing Engine

↓

Overlay Engine

↓

Renderer (CustomPainter)

↓

Capture

---

# Vision Backend

The package must never expose implementation details.

Internal implementations may use:

- ML Kit
- MediaPipe
- Apple Vision
- OpenCV

Public API must expose only:

```dart
VisionBackend.auto()
```

The backend should be replaceable without breaking the API.

---

# Renderer

Rendering must use CustomPainter.

Reasons:

- High performance
- Low allocations
- Smooth animation
- Fine-grained drawing control

Widget-based rendering should be avoided unless required.

---

# Overlay System

Every overlay inherits from:

```dart
abstract class FaceOverlay
```

Built-in overlays:

- GlassesOverlay
- SunglassesOverlay
- ContactLensOverlay
- CustomOverlay

Future overlays should require minimal engine changes.

---

# Image Sources

Support Flutter ImageProvider.

Supported types:

- AssetImage
- NetworkImage
- FileImage
- MemoryImage

---

# Tracking

The engine must calculate:

- Translation
- Rotation
- Scaling
- Face confidence
- Face bounding box
- Landmark positions

Tracking must be smoothed to avoid jitter.

---

# Face Support

Version 1 supports one face.

Architecture must allow future multi-face support.

---

# Capture

Version 1 supports image capture only.

Video recording is planned for future releases.

---

# Performance Goals

Target:

- 60 FPS on modern devices
- Stable frame pacing
- Low memory usage
- Minimal object allocations
- Efficient painting

---

# Debug System

Built-in debug tools should support:

- FPS
- Bounding box
- Landmarks
- Eye centers
- Anchors
- Rotation
- Scale
- Confidence

---

# Calibration

Provide calibration tools for overlay alignment.

Calibration must export Dart configuration.

---

# Preview Studio

A companion desktop/web application should allow developers to visually calibrate overlays and export ready-to-use configuration.

---

# Folder Structure

```text
flutter_virtual_tryon/

lib/
    src/
        backend/
        camera/
        tracking/
        renderer/
        overlays/
        calibration/
        capture/
        widgets/
        models/
        utils/

example/

test/

integration_test/

doc/
```

---

# Non-Goals (Version 1)

- 3D models
- Video recording
- Multiple face tracking
- ARKit/ARCore rendering
- Cloud services

These features may be added later without breaking the existing API.
