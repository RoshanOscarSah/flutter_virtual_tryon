# Flutter Package PRD – flutter_virtual_tryon

## Role

You are the lead architect, senior Flutter engineer, computer vision engineer, technical writer, QA engineer, DevOps engineer, and long-term maintainer of a top-tier open-source Flutter package.

Do not build a prototype.

Do not build a demo.

Build a production-quality Flutter package that could realistically become the standard virtual try-on solution on pub.dev.

Think like the maintainer of packages such as `camera`, `go_router`, or `flutter_bloc`.

Every architectural decision must prioritize:

- API stability
- Long-term maintainability
- Excellent developer experience
- Performance
- Documentation
- Testing
- Extensibility
- Backwards compatibility

Never optimize for writing less code.

Optimize for creating an open-source package that developers will confidently use in production.

---

# Package Name

flutter_virtual_tryon

License

MIT

Current version

0.1.0

Repository structure must be suitable for years of maintenance.

---

# Mission

Create a production-ready cross-platform face tracking and overlay engine for Flutter.

This is NOT a glasses package.

Glasses are only one implementation.

The package should allow developers to attach any overlay to tracked facial landmarks.

Example:

```dart
VirtualTryOn(
  overlays: [
    GlassesOverlay(
      image: AssetImage("rayban.png"),
    ),
  ],
)
```

The package must be generic enough that future overlays such as hats, earrings, masks, helmets, hair, makeup, jewelry and custom overlays can all reuse the same engine.

---

# Target Developers

Primary audience

- Optical shops
- Eyewear stores
- E-commerce apps
- Flutter developers
- Camera applications

The package should hide all computer vision complexity.

The average Flutter developer should have virtual try-on working in under five minutes.

---

# Supported Platforms

Version 1 goals

✅ Android

✅ iOS

✅ Web

✅ macOS

The public API must remain identical across every platform.

Unsupported features should degrade gracefully.

---

# Backend Architecture

The public API MUST NEVER expose implementation details such as:

- Google ML Kit
- MediaPipe
- Apple Vision
- OpenCV

Create an abstraction.

Example:

```dart
VisionBackend.auto()
```

Platform implementations should remain internal.

Android

→ ML Kit

iOS

→ ML Kit

Web

→ MediaPipe

macOS

→ Apple Vision when implemented

Future backends should be replaceable without breaking the public API.

---

# Architecture

Use a modular architecture.

Separate:

- Camera
- Face detection
- Landmark extraction
- Tracking
- Smoothing
- Rendering
- Overlay engine
- Capture
- Backend adapters

Every module should be independently testable.

---

# Rendering

Use CustomPainter.

Do not render overlays using ordinary widget trees unless absolutely necessary.

Target smooth rendering.

---

# Overlay System

Create a base abstraction.

```dart
abstract class FaceOverlay {}
```

Built-in overlays

- GlassesOverlay
- SunglassesOverlay
- ContactLensOverlay
- CustomOverlay

Future overlays must require little or no engine changes.

---

# Image Support

Support Flutter's standard ImageProvider API.

Developers should be able to use:

- AssetImage
- NetworkImage
- MemoryImage
- FileImage

without changing APIs.

---

# Tracking

Implement

- translation
- scaling
- rotation
- smoothing

Tracking should feel stable and natural.

Avoid visible jitter.

Provide configurable smoothing.

---

# Face Tracking

Support one face only.

Future architecture should allow multiple faces.

---

# Contact Lens

Support realistic iris textures when possible.

Provide automatic fallback when iris tracking is unavailable.

---

# Performance Modes

Provide

Fast

Balanced

High Accuracy

Developers should choose performance vs quality.

---

# Face Loss

Support configurable behavior.

Examples

Hide overlay

Freeze overlay

Fade overlay

Custom callback

---

# Capture

Support image capture.

Video recording is out of scope for version one.

---

# Public Widget

```dart
VirtualTryOn(
    backend: VisionBackend.auto(),

    cameraLens: CameraLens.front,

    mirror: true,

    smoothTracking: true,

    performanceMode: PerformanceMode.balanced,

    debugMode: false,

    overlays: [
        GlassesOverlay(...),
        SunglassesOverlay(...),
        ContactLensOverlay(...),
        CustomOverlay(...),
    ],
)
```

Design a polished, stable, and intuitive API.

---

# Rich Callback API

Expose:

- onInitialized
- onFaceDetected
- onFaceUpdated
- onFaceLost
- onCapture
- onError

The tracking callback should expose rich data including rotation, scale, translation, confidence, landmarks, and FPS.

---

# Raw Tracking Data

Expose a stable model that includes values such as:

- faceCenter
- boundingBox
- confidence
- rotation
- translation
- scale
- leftEye
- rightEye
- leftIris
- rightIris
- nose
- forehead
- chin
- leftEar
- rightEar
- faceWidth
- faceHeight
- trackingState

Document every property thoroughly.

---

# Built-in Debug Tools

Provide a developer overlay.

Example

```dart
DebugOptions(
    showFPS: true,
    showFaceBox: true,
    showLandmarks: true,
    showAnchors: true,
    showEyeCenters: true,
    showRotation: true,
    showScale: true,
    showTrackingConfidence: true,
)
```

This should be invaluable for debugging alignment.

---

# Calibration Mode

Provide a way to calibrate overlays visually.

Developers should adjust:

- scale
- rotation
- offset

Export configuration directly into Dart code.

Example output

```dart
GlassesOverlay(
    image: AssetImage(...),
    scaleMultiplier: 1.08,
    offset: Offset(4,-3),
    rotationOffset: 1.5,
)
```

---

# Overlay Constraints

Support built-in visibility constraints.

Example

```dart
GlassesOverlay(
    visibleWhen: OverlayConstraints(
        maxHeadTilt: 40,
        minFaceSize: 120,
        requireBothEyes: true,
    ),
)
```

Developers should not need to write custom visibility logic.

---

# Overlay Preview Studio

Build a companion preview application.

Purpose

Developers drag an overlay image.

Enable webcam.

Adjust

- offset
- scale
- rotation

Click Export.

Generate ready-to-use Dart configuration.

This tool should dramatically reduce integration time.

---

# Documentation

Write production-quality documentation.

Include

- Installation
- Quick Start
- Basic Usage
- Advanced Usage
- Custom Overlays
- Calibration Guide
- Performance Guide
- Platform Notes
- Backend Architecture
- API Reference
- FAQ
- Troubleshooting
- Migration Guide
- Contributing Guide

---

# Example Applications

Provide multiple example apps.

Minimum example

Optical shop example

E-commerce example

Custom overlay example

Debug mode example

Performance mode example

---

# Testing

Create extensive automated tests.

Unit tests

Widget tests

Integration tests where practical

Golden tests

Backend mock tests

Mathematical tests

Tracking tests

Regression tests

Target very high test coverage.

---

# Performance

Benchmark performance.

Target:

- 60 FPS on modern devices
- Stable frame pacing
- Low memory allocations
- Efficient rendering
- No unnecessary object creation every frame

Document optimization decisions.

---

# Accessibility

Ensure example applications follow Flutter accessibility best practices where applicable.

---

# Open Source Standards

Generate:

- README
- CHANGELOG
- LICENSE
- CONTRIBUTING
- CODE_OF_CONDUCT
- SECURITY
- Issue templates
- Pull request template
- GitHub Actions CI

Optimize for an excellent pub.dev package score.

---

# Release Process

Before every release ensure:

- flutter analyze passes
- flutter test passes
- formatting passes
- documentation is updated
- CHANGELOG updated
- pub publish dry run succeeds

Never release broken builds.

---

# Development Strategy

Do NOT attempt to build everything at once.

Instead:

1. Design architecture.
2. Freeze public API.
3. Implement the engine.
4. Implement GlassesOverlay.
5. Add SunglassesOverlay.
6. Add ContactLensOverlay.
7. Add calibration.
8. Add preview studio.
9. Complete documentation.
10. Complete testing.
11. Prepare pub.dev release.

Each milestone must be production-ready before moving to the next.

Do not continue to the next milestone until the current one has been reviewed, tested, documented, and considered complete.

Treat every line of public API as if thousands of Flutter developers will depend on it for years.
