# flutter_virtual_tryon Roadmap

This roadmap defines the development order.

Each milestone must be completed, tested, documented, and reviewed before moving to the next.

---

# Phase 1 — Foundation

- Repository setup
- CI/CD
- Package structure
- Architecture
- Public API freeze
- Documentation skeleton

Status: Complete (M0 2026-07-20: scaffold, CI, OSS files; M1 2026-07-20:
public API implemented, documented, frozen — see API.md addendum)

---

# Phase 2 — Core Engine

- Camera abstraction
- Vision backend abstraction
- Face detection
- Landmark extraction
- Tracking engine
- Smoothing engine

Status: Complete (M2 2026-07-20) — ML Kit (Android/iOS) and MediaPipe
(web) backends wired behind VisionBackend.auto(), both driving a real
camera and emitting real TrackingData. macOS/Windows/Linux report
backendUnavailable (doc/DECISIONS.md #020). Smoothing engine deferred —
not yet implemented; VirtualTryOn.smoothTracking is accepted but unused.
Tracking engine (translation/rotation/scale) already lives on
TrackingData itself (M1) rather than as a separate module.

---

# Phase 3 — Rendering

- CustomPainter renderer
- Overlay engine
- Overlay transformations
- Performance optimization

Status: Complete (M3 2026-07-20) — live CameraPreview wired in (stretch-
fit, see DECISIONS.md #026), GlassesOverlay/SunglassesOverlay paint real
images via a shared OverlayImageResolver + pure OverlayPlacement
geometry, smoothing engine (EMA) implemented, mirroring unified at the
widget level. Performance optimization not separately benchmarked yet —
no per-frame allocations in the hot paint path by construction, but no
profiling pass has been run (see doc/TESTING.md "Performance
Benchmarks", still open).

---

# Phase 4 — GlassesOverlay

- Auto alignment
- Rotation
- Scaling
- Translation
- Constraints
- ImageProvider support

Status: Complete (M3 2026-07-20)

---

# Phase 5 — SunglassesOverlay

- Overlay implementation
- Calibration
- Testing

Status: Complete (M3 2026-07-20) — inherits GlassesOverlay's paint()
directly (same-API design, doc/API.md); no separate calibration/testing
needed beyond what Glasses already covers. Calibration *mode* (Phase 8,
visual scale/rotation/offset tooling) is separate and still Planned.

---

# Phase 6 — ContactLensOverlay

- Iris tracking
- Texture rendering
- Automatic fallback
- Testing

Status: Complete (M4 2026-07-23) — per-eye placement anchored on iris
when available, eye-center fallback otherwise (doc/DECISIONS.md #028).

---

# Phase 7 — Debug Tools

- FPS
- Landmarks
- Bounding boxes
- Anchors
- Confidence
- Scale
- Rotation

Status: Complete (M4 2026-07-23) — all DebugOptions visualizations
implemented; FPS now genuinely measured per-backend (doc/DECISIONS.md
#029/#030), not just a documented-but-dead field.

---

# Phase 8 — Calibration

- Calibration UI
- Export configuration
- Overlay preview

Status: Complete (M5 2026-07-23) — `CalibrationController` +
`OverlayCalibrator` widget; drag/pinch/twist tuning with a live
ready-to-paste `GlassesOverlay(...)`/`SunglassesOverlay(...)` export
panel (doc/DECISIONS.md #032).

---

# Phase 9 — Preview Studio

- Webcam preview
- Overlay editor
- Live adjustments
- Export Dart configuration

Status: Planned — deliberately deferred post-0.1.0. `OverlayCalibrator`
(Phase 8) already covers live adjustments + Dart export inside a normal
Flutter app; a standalone desktop/web companion app is a separate,
larger effort not required to ship 0.1.0.

---

# Phase 10 — Documentation

- README
- Installation
- Tutorials
- API reference
- Examples
- FAQ
- Troubleshooting

Status: Complete (M6 2026-07-23) — `example/` has 5 runnable demos
(quick-start, optical shop, custom overlay, debug mode, calibration)
navigable from a menu screen, verified live on Chrome/web
(doc/DECISIONS.md #033/#034). README rewritten with installation, a
quick-start walkthrough, every built-in overlay, calibration mode, debug
mode, testing with `MockVisionBackend`, and a troubleshooting section
covering the real issues hit building this package (ML Kit
arm64-simulator linking, camera permissions, macOS's no-backend state).
API reference (doc/API.md) and architecture docs (doc/ARCHITECTURE.md)
were already current. Migration Guide intentionally not written yet —
nothing has shipped to migrate from before 0.1.0.

---

# Phase 11 — Testing

- Unit tests
- Widget tests
- Integration tests
- Golden tests
- Performance benchmarks

Status: Unit/widget tests complete (M6 2026-07-23) — 132 tests, 83.4%
overall line coverage; every file at 100% except three that touch real
camera/ML Kit hardware (`io_backend.dart`, `auto_vision_backend.dart`,
`ml_kit_rotation.dart`'s `CameraImage`-consuming half), which this
package's own testing philosophy (doc/TESTING.md, "never depend on a
real camera") deliberately doesn't unit-test — see doc/TESTING.md
"Current Coverage" for the full breakdown. No golden-file tests
(deliberate — pixel-level `RenderRepaintBoundary` captures compared with
exact-value assertions instead, avoiding golden-image platform-rendering
flakiness). Integration tests (`integration_test/`) and performance
benchmarks remain not started — both need real devices/browsers to be
meaningful, out of scope until M7's Kalo Chasma integration surfaces
real-world performance data to benchmark against.

---

# Phase 12 — Release

Requirements before publishing:

- flutter analyze passes
- flutter test passes
- Documentation complete
- CHANGELOG updated
- LICENSE included
- Example application complete
- pub publish --dry-run passes

Release Version:

0.1.0

---

# Long-Term Vision

Future versions may include:

- Multiple face tracking
- Video recording
- Face mesh
- Occlusion
- 3D model support
- ARKit/ARCore integration
- Windows support
- Linux support

These features should be added without breaking the public API.
