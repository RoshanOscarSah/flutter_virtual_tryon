# PROJECT_MEMORY.md

# flutter_virtual_tryon Project Memory

This document summarizes the project's current state.

Read this file before starting any implementation work.

---

# Project

flutter_virtual_tryon

License

MIT

Current Version

0.1.1 (Published — pub.dev/packages/flutter_virtual_tryon)

Repository Status

Published to pub.dev and GitHub
(github.com/RoshanOscarSah/flutter_virtual_tryon)

---

# Vision

Create the standard Flutter package for face tracking and virtual try-on.

The package should hide computer vision complexity behind a simple Flutter API.

---

# Current Goals

- Stable public API
- Cross-platform architecture
- Excellent developer experience
- Production quality
- Long-term maintainability

---

# Supported Platforms

- Android
- iOS
- Web
- macOS

Future

- Windows
- Linux

---

# Public Widget

VirtualTryOn()

This is the primary public entry point.

---

# Current Built-in Overlays

- GlassesOverlay
- SunglassesOverlay
- ContactLensOverlay
- CustomOverlay

---

# Backend

VisionBackend.auto()

Backend implementations remain internal.

---

# Renderer

CustomPainter

---

# Tracking

Supports

- Translation
- Rotation
- Scale
- Smoothing

One face only.

---

# Image Support

Flutter ImageProvider.

---

# Debug Features

- FPS
- Face box
- Landmarks
- Anchors
- Rotation
- Scale
- Confidence

---

# Calibration

Built-in.

Export ready-to-use Dart configuration.

---

# Overlay Preview Studio

Included.

Supports live calibration.

---

# Capture

Image capture only.

Video recording is postponed.

---

# Performance Modes

- Fast
- Balanced
- HighAccuracy

---

# API Philosophy

Simple defaults.

Powerful customization.

Avoid breaking changes.

---

# Current Development Stage

- **M1** (2026-07-20): public API implemented, documented, frozen. All
  types from API.md compile with full dartdoc; MockVisionBackend +
  testing.dart exist.
- **M2** (2026-07-20): real backends wired behind the frozen API. ML Kit
  (Android/iOS) and MediaPipe (web) both drive a real camera + real
  detection; macOS/Windows/Linux report `backendUnavailable` — genuinely
  no auto-detection exists there (corrected from an M1 assumption, see
  DECISIONS.md #020).
- **M3** (2026-07-20): real renderer. Live `CameraPreview`,
  `GlassesOverlay`/`SunglassesOverlay` paint resolved images at the
  correct eye-anchored position/size/rotation (pixel-space geometry, not
  the normalized-space approximation — see DECISIONS.md #024/#026/#027),
  smoothing engine (EMA) implemented, mirroring unified at the widget
  level.
- **M4** (2026-07-23): `ContactLensOverlay` paints per-eye, anchored on
  iris landmarks when available and falling back to eye centers
  otherwise (DECISIONS.md #028); debug overlay implements every
  `DebugOptions` visualization (face box, landmarks, eye centers,
  anchors, text panel — DECISIONS.md #029); `TrackingData.fps`/
  `timestamp` are now genuinely measured per-backend, not dead fields
  (DECISIONS.md #030); `VirtualTryOnController.capture()` implemented via
  a `RepaintBoundary` snapshot, returns null on failure per its original
  M1 contract (DECISIONS.md #031).

- **M5** (2026-07-23): `CalibrationController` (plain `ChangeNotifier`)
  + `OverlayCalibrator` widget for live drag/pinch/twist tuning with a
  ready-to-paste Dart export panel (DECISIONS.md #032). `example/` now
  has 5 runnable demos — quick-start, optical shop, custom overlay,
  debug mode, calibration — navigable from a menu screen, with runtime-
  generated (not bundled/linked) demo artwork (DECISIONS.md #033) and
  iOS/Android camera permissions declared, deliberately not macOS
  (DECISIONS.md #034). Verified live in a real browser (Chrome/web),
  not just via analyzer/unit tests — caught and fixed one genuine
  overflow bug in the optical shop demo layout.

- **M6** (2026-07-23): README rewritten from its pre-implementation
  skeleton into a real reference (installation, quick-start, every
  built-in overlay, calibration mode, debug mode, testing, and a
  troubleshooting section drawn from real issues hit building this
  package). Test coverage review: added targeted tests for every
  under-tested pure-logic path (`FpsTracker`, `VirtualTryOnException`,
  `ContactLensOverlay.rightTexture`, `FaceLossBehavior.custom()`,
  `OverlayImageResolver`'s async/error/dispose paths,
  `MockVisionBackend.detectStill`, debug panel's null-tracking
  placeholders) plus three new `VirtualTryOn` widget-lifecycle tests
  (unsupported custom backend, controller reassignment, backend
  runtime-type change, smoothTracking toggle, init failure). Overall
  coverage rose from 77.0% to 83.4%; every source file is now at 100%
  except the three that require real camera/ML Kit hardware
  (documented in doc/TESTING.md "Current Coverage"). The package was
  split into its own repo (github.com/RoshanOscarSah/flutter_virtual_tryon)
  and **published to pub.dev as 0.1.0** — the first real release.

- **0.1.1** (2026-07-23): dependency-only patch — `camera` raised to
  `^0.12.0` and `google_mlkit_face_detection` to `^0.14.0`, closing the
  gap to their latest stable versions for pub.dev's "up-to-date
  dependencies" score (30/40 → targeting 40/40). No public API changes;
  no Dart-level breaking changes in either dependency, verified via
  analyze + the full test suite. Live-camera behavior on a real device
  against the new versions has not been separately re-verified — flag
  if `google_mlkit_commons` 0.12.0's "enhanced image format validation"
  turns out to reject frames the old version accepted.

132 total tests pass, including genuine (non-golden-file) pixel-level
render tests for GlassesOverlay, ContactLensOverlay, and the debug
overlay.

Next Milestone

M7 — integrate flutter_virtual_tryon into Kalo Chasma itself (replacing
the app's own Vision Mirror internals this package was extracted from).

---

# Rules

Never expose ML Kit.

Never expose MediaPipe.

Never expose Apple Vision.

Never expose OpenCV.

Never break the public API without discussion.

Always document public APIs.

Always write tests.

Always prioritize maintainability over speed.
