# TESTING.md

# flutter_virtual_tryon Testing Strategy

## Purpose

Testing is a core feature of this package.

No feature is considered complete until it has appropriate automated tests and manual verification where necessary.

The goal is to make the package reliable enough for production applications.

---

# Testing Philosophy

We prioritize:

- Correctness
- Stability
- Performance
- Regression prevention
- Cross-platform consistency

Every bug fixed should result in a new regression test whenever possible.

---

# Testing Pyramid

Priority:

1. Unit Tests
2. Widget Tests
3. Integration Tests
4. Manual Device Testing

---

# Unit Tests

Unit tests should cover:

- Math calculations
- Rotation
- Translation
- Scaling
- Smoothing
- Landmark calculations
- Coordinate transforms
- Face loss logic
- Overlay constraints

Unit tests should never depend on a real camera.

---

# Widget Tests

Widget tests should verify:

- VirtualTryOn widget
- Overlay rendering
- Configuration options
- Debug tools
- Error states
- Loading states

---

# Integration Tests

Integration tests should verify:

- Camera initialization
- Face detection pipeline
- Overlay updates
- Image capture
- Backend switching
- Platform initialization

---

# Golden Tests

Golden tests should verify:

- Overlay rendering
- Alignment
- Debug overlays
- Calibration UI

---

# Backend Testing

Every backend must expose identical behavior through the public API.

Backend-specific implementation details should never affect user code.

---

# Mocking

Provide mock implementations for:

- Camera
- Vision backend
- Tracking data
- Image capture

This allows testing without hardware.

---

# Performance Benchmarks

Measure:

- FPS
- Frame time
- Memory usage
- Garbage collection pressure
- Paint time

Performance regressions should be treated as bugs.

---

# Manual Device Testing

Before every release verify on real devices.

Minimum:

Android

- Front camera
- Rear camera
- Portrait
- Landscape

iOS

- Front camera
- Rear camera

Web

- Chrome
- Edge
- Safari (if available)

macOS

- Webcam
- Window resizing

---

# Test Coverage Goals

Public API

100%

Core tracking engine

95%+

Renderer

90%+

Utilities

95%+

Overall

Target 90%+ meaningful coverage.

---

# Continuous Integration

Every Pull Request must run:

- flutter analyze
- flutter test
- formatting checks

No failing tests may be merged.

---

# Regression Policy

Every reported bug should produce:

1. A failing test.
2. A fix.
3. A passing test.

Never fix bugs without preventing regression.

---

# Current Coverage (M6, 2026-07-23)

`flutter test --coverage`: 132 tests, 83.4% overall line coverage
(613/735). Every file is at 100% except three that touch real camera/
platform hardware:

- `lib/src/backend/io_backend.dart` (1.2%) — the live ML Kit + `camera`
  engine. Exercising it for real needs a physical camera and device;
  `MockVisionBackend` (`package:flutter_virtual_tryon/testing.dart`) is
  the supported seam for testing everything that sits above it, per this
  document's "Unit tests should never depend on a real camera" rule.
- `lib/src/backend/auto_vision_backend.dart` (5.9%) — a thin delegate
  around whichever engine `platform_backend.dart` selects; same
  reasoning.
- `lib/src/backend/ml_kit_rotation.dart` (36.7%) — its pure coordinate
  math (`mlKitUprightPoint`/`mlKitUprightSize`) is fully covered
  (`test/ml_kit_conversion_test.dart`); only
  `mlKitInputImageFromCameraImage`, which needs a real `CameraImage` +
  `CameraController`, is not.

This matches the donor-code reality documented in
doc/HANDOVER.md — these three files are the ones that talk to actual
camera/ML Kit plugins rather than pure data transforms — and is
consistent with the "Overall 90%+" goal above being aspirational for
platform-integration code specifically, not a violation of it. Manual
device testing (this document, "Manual Device Testing") is what actually
verifies these paths; automate that assertion further only if a mocking
strategy for `camera`/`google_mlkit_face_detection` proves worth the
added test complexity.

---

# Release Testing Checklist

Before every release:

✓ Analyze passes

✓ Tests pass

✓ Manual testing completed

✓ Example app verified

✓ Performance benchmark acceptable

✓ Documentation updated

Only then is the package considered releasable.