# HANDOVER.md

Session handover for implementing `flutter_virtual_tryon`. Read this FIRST,
then CLAUDE.md's reading lists for the task at hand. Written 2026-07-20 by the
session that fixed Kalo Chasma's iOS simulator build and App Store rejections.

---

# What this is

A greenfield pub.dev package (docs-only today — there is **no code yet**, only
`doc/` and `.ai/`). It is a generic face-tracking + overlay engine whose
public API is already designed in doc/API.md. The 12-phase roadmap in
doc/ROADMAP.md has been condensed into 8 working milestones (M0–M7) in the
session task list; each milestone maps to one or more roadmap phases.

**The single most important fact:** this package is largely an *extraction and
generalization* of code that already works in production in the host app.
Do not design the CV pipeline from scratch — port it.

---

# Name availability (verified 2026-07-20)

`flutter_virtual_tryon` returns 404 on `pub.dev/api/packages/…` — **the name
is free**. The niche is basically empty (nearest: `ar_tryon_view`,
`jeweltry`, `ammazza_webar_flutter` — none established).

---

# The donor code (Kalo Chasma, repo root = parent directory)

Everything to extract lives in `../lib/features/virtual_try_on/`:

| File | What it is | Package destination |
|---|---|---|
| `face_aligner_base.dart` | `FaceAligner` abstraction + `FaceAlignment` model (eye centers, roll, confidence) | `lib/src/backend/` (becomes the internal seam behind `VisionBackend`) |
| `face_aligner_io.dart` | ML Kit backend (Android + iOS), incl. live-stream path (nv21/bgra8888) | `lib/src/backend/` |
| `face_aligner_web.dart` | MediaPipe Face Landmarker via JS interop | `lib/src/backend/` |
| `face_aligner_stub.dart` | No-op for unsupported platforms (macOS desktop) | `lib/src/backend/` |
| `face_aligner.dart` | Conditional export wiring the three above | same pattern |
| `try_on_engine.dart` | Camera lifecycle + alignment engine (`supportsLiveCamera` / `supportsAutoAlignment` / `supportsLiveStream` capability flags — keep this capability-flag pattern, it is good) | `lib/src/camera/` + `lib/src/tracking/` |
| `try_on_screen.dart` | UI: rendering, manual drag/pinch/rotate fallback, photo mode, pre-permission screen | NOT ported wholesale — mine it for renderer math and fallback UX; the package's `VirtualTryOn` widget replaces it |
| `../doc/TRY_ON.md` | 88-line doc of the existing system | background reading |

Web MediaPipe setup lives in `../web/index.html` (script/wasm loader). The
package must either self-contain this or document it as a required index.html
addition — decide in M2 and record in DECISIONS.md.

---

# Hard-won platform facts (do not rediscover these the hard way)

1. **`camera` has NO macOS implementation.** `camera_avfoundation` declares
   `platforms: ios:` only. doc/ARCHITECTURE.md's "macOS ✅" can only mean
   *photo-based* try-on (bytes in → alignment out → overlay render), which is
   exactly what Kalo Chasma ships on macOS. Live macOS camera would require
   `camera_macos` (separate, less maintained) or an Apple Vision backend —
   both out of scope for 0.1.0. Degrade gracefully; document it.
2. **ML Kit has no iris landmarks; MediaPipe does.** ContactLensOverlay's
   "automatic fallback" (doc/API.md) means: iris anchor on web, eye-center
   anchor on Android/iOS.
3. **ML Kit pods don't ship arm64-simulator slices.** Any consumer of
   `google_mlkit_face_detection` hits "Building for iOS-simulator, but
   linking in object file built for iOS" on Apple-silicon iOS 26+ sims
   (which are arm64-only). Kalo Chasma's fix: `../tool/strip_ios_device_platform.py`
   (strips the platform load command from the vendored arm64 objects — they
   then link for BOTH device and simulator; device/App Store builds verified
   unaffected) + a Podfile post_install hook + target-level
   `EXCLUDED_ARCHS[sdk=iphonesimulator*] = i386` override (Flutter propagates
   any pod-level arm64 exclusion to the whole app). The package's example app
   needs the same treatment, and the README's platform notes should mention it.
4. **Flutter tool check:** flutter_tools greps `xcodebuild -showBuildSettings`
   of Pods.xcodeproj for `EXCLUDED_ARCHS.*arm64` — resolved settings, so a
   target-level override beats the MLKit podspec xcconfig.
5. `google_mlkit_face_detection` currently used at 0.13.2 (0.14.0 available);
   camera 0.11.x. Pin compatible ranges in the package pubspec.

---

# Structure & publishing decisions still open (decide in M0, record in DECISIONS.md)

- **Repo location:** currently an untracked folder inside the KaloChasma git
  repo. Fine for development (Kalo Chasma consumes it as a path dependency),
  but pub.dev wants `repository:`/`homepage:` URLs → needs its own GitHub
  repo before M6 publish. Recommendation: develop nested now, `git init` /
  split before release; don't block early milestones on it.
- **Preview Studio** (roadmap phase 9) is deferred past 0.1.0 — update
  ROADMAP.md status lines as milestones complete (they all say "Planned").
- **pub.dev publisher:** user action — needs their Google account / verified
  publisher. Ask before M6.

---

# Working agreements (from the docs — binding)

- Public API per doc/API.md is designed; M1 makes it compile + freezes it.
  After M1, changes to the public surface need explicit discussion.
- Never expose ML Kit / MediaPipe / Apple Vision types (DECISIONS.md #004).
- CustomPainter rendering, no per-frame allocations (DECISIONS.md #003).
- Every public member documented; every feature tested; every bug gets a
  regression test (CODING_STANDARDS.md, TESTING.md).
- Milestones complete in order; don't start M(n+1) until M(n) is reviewed,
  tested, documented (PRODUCT_REQUIREMENTS.md "Development Strategy").

---

# Host-app context that matters here

- Kalo Chasma is mid App-Store review (v1.0.5+7 iOS resubmission; macOS needs
  a new binary with the camera entitlement removed — already done in the
  host repo). **Do not let package work destabilize the host app**; keep
  `../lib/features/virtual_try_on/` untouched until M7 (integration).
- Kalo Chasma try-on assets (transparent glasses PNGs) are hosted at
  kalochasma-demo-assets.web.app — usable as example-app assets.
- Host repo test suite: 48 tests, `flutter analyze` clean — keep it that way
  through M7.

---

# Suggested first command of the next session

Read TaskList (milestones M0–M7 = tasks #20–#27), then start M0 (#20):
scaffold the package. `flutter create --template=package` inside
`flutter_virtual_tryon/` (it tolerates the existing doc/), then shape
`lib/src/` per ARCHITECTURE.md's folder structure.

---

# M2 Correction (2026-07-20)

The macOS note above ("photo-based mode: bytes in → alignment out")
turned out to be wrong once the donor code was traced fully: ML Kit's own
`isSupported` gate guards *both* its live-stream and its still-image
detection paths, and both are Android/iOS only. There is no working
auto-detection on macOS in the donor app at all today — only manual
drag/pinch/rotate. `VisionBackend.auto()` now reports
`backendUnavailable` on macOS entirely, matching that reality. See
doc/DECISIONS.md #020.
