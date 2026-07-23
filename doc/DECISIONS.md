# DECISIONS.md

# flutter_virtual_tryon Architecture Decisions

This document records **why** important technical decisions were made.

Future contributors (human or AI) should read this document before proposing architectural changes.

---

# Decision 001

## Public API First

Status

Accepted

Reason

The package is intended to become a long-term production dependency.

Changing public APIs is expensive for downstream developers.

Rule

Implementation may change.

Public API should remain stable whenever possible.

---

# Decision 002

## Package Goal

Status

Accepted

Decision

This package is **not** a glasses package.

It is a generic face tracking and overlay engine.

Reason

This enables future overlays without redesigning the architecture.

Examples include:

- Glasses
- Sunglasses
- Contact lenses
- Hats
- Earrings
- Makeup
- Masks
- Helmets
- Custom overlays

---

# Decision 003

## Rendering Engine

Status

Accepted

Decision

Use CustomPainter.

Rejected

Rendering overlays as ordinary Flutter widgets.

Reason

CustomPainter provides:

- Better performance
- Lower memory allocations
- More predictable rendering
- Better frame pacing
- Easier control over transformations

---

# Decision 004

## Backend Abstraction

Status

Accepted

Decision

Hide all computer vision implementations behind VisionBackend.

Never expose:

- Google ML Kit
- MediaPipe
- Apple Vision
- OpenCV

Reason

Developers should not need to know which backend is active.

Future backend changes must not require API changes.

---

# Decision 005

## Image Source

Status

Accepted

Decision

Support Flutter ImageProvider.

Reason

Developers automatically gain support for:

- AssetImage
- NetworkImage
- FileImage
- MemoryImage

without additional APIs.

---

# Decision 006

## Supported Platforms

Version 1

Android

iOS

Web

macOS

Reason

These platforms satisfy the project's primary target audience.

Windows and Linux remain future goals.

---

# Decision 007

## Face Support

Version 1 supports one face.

Reason

This keeps the engine simpler, faster, and easier to maintain.

Architecture must allow future multi-face support.

---

# Decision 008

## Public API Philosophy

Decision

Simple defaults.

Advanced customization.

The simplest use case should require only a few lines of code.

Advanced developers should still have extensive configuration options.

---

# Decision 009

## Debug System

Decision

Provide professional debugging tools.

Reason

Debugging overlay alignment is difficult.

Built-in visualization dramatically improves developer experience.

---

# Decision 010

## Calibration

Decision

Calibration is a built-in feature.

Reason

Developers should never have to guess offset or scaling values manually.

---

# Decision 011

## Overlay Preview Studio

Decision

Ship a companion preview tool.

Reason

Visual calibration greatly improves productivity and lowers integration time.

---

# Decision 012

## Testing Philosophy

Every public API must be tested.

Every bug should result in a regression test.

Performance-sensitive code should be benchmarked.

---

# Decision 013

## Documentation

Documentation is considered part of the product.

A feature is not complete until it is documented.

---

# Decision 014

## Open Source Standards

This repository should be maintained as a professional open-source project.

All changes should prioritize:

- Stability
- Maintainability
- Developer Experience
- Documentation
- Testing
- Performance

over rapid feature development.

---

# Decision 015

## Normalized, unmirrored, subject-relative coordinates

Status: Accepted (M1)

All `TrackingData` geometry is normalized to the analyzed frame (0–1,
y-down), unmirrored, with left/right meaning the subject's own sides.

Reason: resolution-independent (camera vs preview size never leaks into
app code), one consistent space across live/photo/backends, and the
convention both ML Kit and MediaPipe already use.

---

# Decision 016

## Tracking state lives on the controller, not on TrackingData

Status: Accepted (M1)

`TrackingData` exists only for real detections; `TrackingState`
(initializing/tracking/lost) is exposed by `VirtualTryOnController`.

Reason: no half-valid measurements with nullable-everything fields; the
required fields (box, eyes, confidence) can stay non-null.

---

# Decision 017

## VirtualTryOnController

Status: Accepted (M1)

A controller (optional widget param) provides `capture()`,
`trackingState`, `lastTrackingData`.

Reason: API.md defined `onCapture` but nothing that triggers a capture.
The controller is the standard Flutter pattern (CameraController,
TransformationController) and is purely additive.

---

# Decision 018

## FaceLossBehavior is a sealed class hierarchy

Status: Accepted (M1)

`hide()` / `freeze()` / `fade(duration:)` / `custom()` as sealed
subclasses with const factories, instead of an enum.

Reason: fade needs configuration (duration), future variants may too;
sealed classes keep switches exhaustive. `onFaceLost` always fires;
`custom()` means "no built-in visual action, app reacts via callback".

---

# Decision 019

## Public testing library with MockVisionBackend

Status: Accepted (M1)

`package:flutter_virtual_tryon/testing.dart` ships a scriptable
`MockVisionBackend`.

Reason: consumers must be able to widget-test try-on flows without
cameras or ML models; we need the same tool ourselves, and keeping it
public avoids everyone reinventing a worse one. Custom *production*
backends remain unsupported (the engine contract stays internal).

---

# Decision 020

## macOS (and other non-mobile io platforms) get zero auto-detection in 0.1.0

Status: Accepted (M2)

`VisionBackend.auto()` reports `backendUnavailable` on macOS/Windows/Linux
entirely — not a degraded "photo-based" mode. This corrects an earlier
assumption in doc/HANDOVER.md.

Reason: tracing the donor implementation found that ML Kit's own
`isSupported` gate (Android/iOS only) blocks *both* its live-stream path
and its still-image (`detectStill`) path — there's no working auto-align
of any kind on desktop today, only manual drag/pinch/rotate in the host
app's own UI. Claiming "photo mode" as an M2 deliverable would have
built a feature the donor app never actually had. A future milestone
could add an Apple Vision backend for macOS; out of scope for 0.1.0.

---

# Decision 021

## Web backend self-injects its JS bridge; no index.html edit required

Status: Accepted (M2)

The MediaPipe bridge script is injected into the page at runtime
(`web_bridge.dart`, guarded so it runs once per page) instead of
requiring consumers to hand-edit `web/index.html`, which is how the
donor implementation did it.

Reason: `doc/VISION.md` — "installation should be straightforward" —
and a required manual index.html edit is exactly the kind of setup
friction that contradicts it. A `<script type="module">` element's
`load` event fires once its static imports and top-level body finish
executing, which is a reliable, standard signal that needs no
Promise-passing scheme back into Dart.

---

# Decision 022

## MediaPipe ear landmarks intentionally omitted

Status: Accepted (M2)

`TrackingData.leftEar`/`rightEar` stay null on the web backend.

Reason: MediaPipe's 468-point mesh indices for nose/chin/forehead/eye
corners/iris were all proven in the donor's production code; ear
indices were not. Shipping a guessed index risks silently swapping left
and right — worse than the documented null this field already supports.
Revisit if verified indices are found.

---

# Decision 023

## SDK floor raised to Dart 3.3 / Flutter 3.19

Status: Accepted (M2)

`environment.sdk` moved from `>=3.0.0` to `>=3.3.0`.

Reason: the web vision backend's JS interop (`web_bridge.dart`) uses
extension types to type the bridge object, which requires Dart 3.3.
Flutter 3.19 is the first stable release bundling it. Still a broad
compatibility floor, just not artificially lower than what the code
actually needs.

---

# Decision 024

## Image resolution is a shared, semi-internal utility on FaceOverlayPaintContext

Status: Accepted (M3)

`FaceOverlayPaintContext` gained two new fields: `images`
(`OverlayImageResolver`) and `imageConfiguration`. `GlassesOverlay`/
`SunglassesOverlay` use them internally; the types are reachable from a
`CustomOverlay` too but aren't exported from the package's public barrel
(`flutter_virtual_tryon.dart`) or documented in `doc/API.md`.

Reason: the frozen architecture requires overlays to paint via `Canvas`
(#003), which can't just drop in an `Image.asset()` widget — some form of
eager image resolution + cross-frame caching is unavoidable. Rather than
have every overlay (built-in or third-party) reinvent `ImageStream`
bookkeeping, one resolver is owned per `VirtualTryOn` and threaded
through the paint context — the same "give everyone the good tool we
built for ourselves" reasoning as #019 (`MockVisionBackend`). It's kept
out of the *documented* public surface for now because its shape hasn't
been proven against real third-party use yet; promoting it to a fully
documented, API.md-listed capability is a natural, non-breaking future
step once it has.

---

# Decision 025

## Smoothing engine: exponential moving average, reset on face-loss gaps

Status: Accepted (M3)

`TrackingSmoother` (internal) implements `VirtualTryOn.smoothTracking`
via a simple EMA over every landmark/bounding-box field, with a fixed
`alpha = 0.35`. Optional landmarks that appear/disappear between frames
snap in/out rather than blending against a missing value. The smoother
resets on every face-loss (`_handleTracking`'s null branch), so
reacquisition never blends the fresh position against a stale one from
before the gap.

Reason: matches doc/ARCHITECTURE.md's "smoothing engine" requirement
with the simplest technique that avoids visible jitter without adding a
second tunable parameter to the frozen public API — `smoothTracking`
stays a bool. `alpha = 0.35` was picked as a reasonable middle ground
(enough lag to flatten single-frame noise, not so much that fast head
movement visibly trails) rather than benchmarked against real detector
noise; revisit if real-device testing (see doc/TESTING.md) shows it
needs tuning.

---

# Decision 026

## Camera preview fills its box via stretch, not crop-to-cover

Status: Accepted (M3)

`VirtualTryOn` renders the live camera feed via `CameraPreview` inside a
`Stack(fit: StackFit.expand)`. Under Flutter's layout rules this gives
`CameraPreview`'s internal `AspectRatio` tight constraints in both axes,
which forces it to fill the box exactly — stretching the image
non-uniformly when the box's aspect ratio doesn't match the camera's,
rather than cropping (`BoxFit.cover`) or letterboxing (`BoxFit.contain`).

Reason: overlay alignment stays correct either way — `TrackingData`'s
normalized coordinates are mapped onto the *same* box the camera image
is stretched into, so both undergo the identical transform and nothing
misaligns. A true crop-to-cover would look better in the mismatched-
aspect-ratio case but needs extra geometry (sizing a fixed box to the
camera's native resolution, then `FittedBox`-cropping it) that isn't
core to shipping correct overlay rendering. Deferred, not forgotten —
worth revisiting once there's a real device/aspect-ratio combination to
design against rather than guessing.

---

# Decision 027

## Mirroring moved from per-overlay canvas transform to one widget-level Transform.flip

Status: Accepted (M3)

`VirtualTryOn.mirror` now wraps the camera preview *and* the overlay
`CustomPaint` together in a single `Transform.flip`, rather than each
overlay-paint call applying `canvas.translate`/`scale` itself (M1's
original approach, before a real camera image existed to mirror in
lockstep).

Reason: with a real camera preview now in the tree, the image and the
overlays must flip as one visual unit — doing it once at the widget
level guarantees they can't drift out of sync, and is simpler than
replicating the same flip math in every painter.

---

# Decision 028

## Contact lens sizing uses a fixed anatomical ratio, not a second tunable

Status: Accepted (M4)

`ContactLensOverlay`'s automatic size is `eyeDistancePx * 0.19 * irisScale`
— 0.19 is a fixed constant (average iris diameter ÷ average eye
distance), not something the frozen API exposes as its own parameter.
`irisScale` (already in API.md) is the only adjustment knob.

Reason: matches the same "simple defaults, one multiplier" pattern
`GlassesOverlay.scaleMultiplier` already established (`eyeDistanceMultiplier`
in `OverlayPlacement.forImage` is likewise an internal constant, not
public). Keeping the anatomical ratio internal avoids a second public
number developers would have to understand just to get a reasonable
default.

---

# Decision 029

## Debug overlay renders inside the same mirror transform as everything else

Status: Accepted (M4)

`VirtualTryOn.debugMode`'s visualizations are painted inside the same
`Transform.flip` that wraps the camera preview and overlays, not as a
separate unmirrored layer.

Reason: the debug overlay's whole purpose is verifying alignment — a
face box or landmark dot that's *positioned* correctly but rendered
outside the mirror transform would show up on the wrong side of a
mirrored preview, which is actively misleading for exactly the
debugging job this feature exists to do. Trade-off: the text panel
(FPS/rotation/scale/confidence) reads mirrored too when `mirror` is on.
Accepted as the lesser problem — a developer can read mirrored text,
but a misaligned marker defeats the tool's purpose.

---

# Decision 030

## FPS is measured per-backend, not derived centrally

Status: Accepted (M4)

`TrackingData.fps`/`timestamp` (declared in M1, unused until now) are
populated by each backend itself (`FpsTracker`, ticked once per
processed frame — including frames with no face — so it reflects true
detector throughput, not "frames with a face"). On the MediaPipe
backend, only the live periodic-capture loop ticks it; one-off
`detectStill()` calls don't, since a frame rate isn't meaningful for an
isolated still detection.

Reason: FPS is inherently about the *engine's* frame cadence, which only
the stateful backend classes know — the pure conversion functions
(`mlKitFaceToTrackingData`, `mediaPipeLandmarksToTrackingData`) stay
single-frame-scoped and testable with fixtures; they just accept and
pass through whatever fps/timestamp the caller measured.

---

# Decision 031

## capture() is a best-effort snapshot; failures return null, never throw

Status: Accepted (M4)

`VirtualTryOnController.capture()` wraps its `RenderRepaintBoundary.toImage()`
call in a try/catch and returns null on any failure — not attached, not
yet painted, or the engine can't rasterize right now.

Reason: this was already the documented M1 contract ("Returns null when
capture isn't currently possible"); implementing it now just fulfills
that promise. A capture failing is a normal, expected outcome for a
UI-triggered action (the widget could be mid-teardown, off-screen, etc.),
not exceptional — matching `CODING_STANDARDS.md`'s error-handling
guidance to validate only at real boundaries, not invent handling for
impossible cases.

---

# Decision 032

## CalibrationController is a plain ChangeNotifier; gesture math lives in the widget

Status: Accepted (M5)

`CalibrationController` holds only `scaleMultiplier`/`offset`/
`rotationOffset` plus `update()`/`reset()`/`exportDartCode()` — it has no
knowledge of `GestureDetector` or Flutter's gesture callbacks at all.
`OverlayCalibrator` (the widget) captures base values in `onScaleStart`
and computes absolute new values from `ScaleUpdateDetails` in
`onScaleUpdate`, then calls `controller.update(...)`.

Reason: `ScaleUpdateDetails.scale`/`.rotation` are cumulative since
gesture start, not incremental — that math is inherently tied to
Flutter's gesture system and has nothing to do with what a calibration
value *is*. Keeping the controller a pure data+notify class means its
core logic (clamping, change-detection, export formatting) is unit
tested without a widget tree, matching the same controller/widget split
`VirtualTryOnController` already established (#017).

---

# Decision 033

## Example demos generate their overlay artwork at runtime instead of bundling or linking assets

Status: Accepted (M5)

`example/lib/demo_glasses.dart` draws a glasses silhouette via
`dart:ui`'s `PictureRecorder`/`Canvas`/`Picture.toImage()` and returns
PNG bytes, used as a `MemoryImage` across all five example demos.

Reason: the example needed *something* to render as overlay artwork.
Bundling binary image assets in the package/example bloats the repo and
implies official "included" artwork that doesn't exist; linking to a
guessed external image URL is unverifiable and could break or 404
silently. Generating a simple shape at runtime is fully self-contained,
requires no network, and makes clear to anyone reading the example that
real apps should supply their own product photography via
`AssetImage`/`NetworkImage`/`FileImage` — the whole point being
demonstrated is `ImageProvider` flexibility (#005), not the artwork
itself.

---

# Decision 034

## Example app's camera permissions cover iOS/Android only, not macOS

Status: Accepted (M5)

`example/ios/Runner/Info.plist` and
`example/android/.../AndroidManifest.xml` both declare camera usage; no
equivalent entitlement was added for the example's macOS target.

Reason: `VisionBackend.auto()` reports `backendUnavailable` on macOS —
there is no auto-detection backend there at all (#020). Declaring a
camera entitlement the app can never actually use to drive tracking
would misrepresent the app's real capabilities to reviewers, repeating
the exact App Store rejection scenario #020 was written to avoid. The
example still runs on macOS (calibration/debug demos work without a
detected face), it just won't request camera access there.

---

# Decision 035

## ML Kit live coordinates are already upright on iOS, raw on Android — rotate only Android

Status: Accepted (0.1.3, post-M7). Supersedes a wrong first diagnosis in
0.1.2 (see below).

`IoVisionBackendEngine._onFrame` branches on platform when turning a
detected `Face` into `TrackingData`:

- **iOS**: call `mlKitFaceToTrackingData(face, rawSize)` — normalize the
  detector's points directly against the raw buffer dimensions, apply
  *no* rotation.
- **Android**: call it with `rawSize` + `rotation` so `mlKitUprightPoint`
  rotates the raw-sensor-space points upright, normalized against the
  width/height-swapped upright size.

Reason: a real device bug — on a live iOS camera the overlay's eyes/nose/
chin stacked into a vertical line down one side of the face
(`debugMode`-confirmed). The `camera` plugin delivers an
*already-display-oriented* buffer on iOS, so ML Kit returns detections
already upright; the code was then rotating them a second time via
`mlKitUprightPoint`, turning a level face 90°. Google's own
`packages/example/.../coordinates_translator.dart` encodes exactly this
platform split: for a 90°/270° rotation it divides iOS points by the raw
`imageSize` (no axis swap) but Android points by the swapped dimension —
i.e. iOS points are already upright, Android's are not. The rotation
handed to ML Kit stays asymmetric too (iOS = `sensorOrientation`;
Android = combined with `deviceOrientation`), matching that same recipe.

**Second, compounding iOS bug — mirrored handedness (also 0.1.3):** with
the rotation corrected, eye-anchored overlays then rendered *upside down*.
The iOS front-camera buffer is mirrored, so ML Kit reports the subject's
left eye at a *smaller* x than their right — the reverse of
`TrackingData`'s unmirrored, subject-left-on-frame's-right convention
(#015). That reversed the eye vector `_EyeGeometry` derives head-roll
from, flipping glasses 180°. The fix `swapLeftRight` *relabels* which ML
Kit landmark feeds `leftEye`/`rightEye` (and the ears), it does **not**
mirror the coordinates. This distinction is the crux: `VirtualTryOn`
keeps the camera preview and the overlay `CustomPaint` as siblings inside
one `Transform.flip` (#027) and mirrors both together, so the overlay's
coordinates must stay in the same raw-buffer space as the preview to line
up. Mirroring the overlay's x (the tempting fix) *does* correct rotation
but shifts the overlay to the mirror-image x-position — visibly off to
one side on an off-center face. Relabeling reverses the eye vector
(fixing rotation) while leaving the eye midpoint — the overlay's anchor —
exactly in place. (A false-start 0.1.3 build did mirror the coordinates
and reproduced the off-to-one-side symptom on-device before this
relabel-instead approach; verified via the same local `path:` dependency
loop.)

**Wrong first attempt (0.1.2), kept as a caution:** the initial fix
instead unified the *rotation-metadata* computation to combine
`sensorOrientation` with `deviceOrientation` on iOS as well, on the
theory that ignoring device orientation was the bug. It wasn't — and the
change was a no-op in portrait (portrait contributes 0° of compensation),
which is precisely why the reported portrait misalignment survived it.
The lesson: this was a *coordinate-space* bug (what space ML Kit reports
in), not a *rotation-metadata* bug (what orientation ML Kit reads the
buffer as). Verify a platform-specific CV fix on the actual platform
before shipping — 0.1.3 was validated on-device against a local `path:`
dependency before publishing.

---

# Decision 036

## Still-image try-on takes encoded bytes and sizes to an aspect-ratio box

Status: Accepted (0.2.0)

`VirtualTryOnImage` (the still-photo sibling of `VirtualTryOn`) takes the
photo as a `Uint8List` of *encoded* bytes, and renders the photo + overlays
inside an `AspectRatio` locked to the image's own pixel dimensions.

Reason (bytes, not `ImageProvider`): detection genuinely needs the encoded
image — `detectStill` feeds ML Kit a real file path on iOS/Android and
MediaPipe a blob on web; neither can consume a decoded `ui.Image`. A
`Uint8List` is also exactly what every realistic source hands you
(`image_picker`'s `XFile.readAsBytes`, `File.readAsBytes`,
`rootBundle.load`). Taking an `ImageProvider` would be more Flutter-idiomatic
but couldn't reliably recover encoded bytes for detection (an `AssetImage`/
`NetworkImage` only exposes a decoded image), so it would be a lie for the
general case. Convenience `.asset`/`.file`/`.network` constructors that
resolve to bytes can be added later without breaking the bytes API.

Reason (aspect-ratio box, not letterbox mapping): the overlays' normalized
`TrackingData` coordinates map to the paint `size` by a plain multiply
(`FaceOverlayPaintContext.size`). If the photo were shown with
`BoxFit.contain` inside an arbitrary box, the displayed image would occupy a
letterboxed sub-rect and the overlays would need that rect's offset/scale
applied — reintroducing exactly the `_BoxFitTransform` mapping the donor app
carried. Locking the whole unit to the image's aspect ratio (image at
`BoxFit.fill`, box AR == image AR, so no distortion) keeps the coordinate
mapping linear and identical to the live widget's, and defers fitting-into-
the-layout to the standard `AspectRatio` the consumer already knows.

`mirror` defaults to `false` here (a saved photo isn't selfie-mirrored like
a live preview), and no `swapLeftRight` is applied — a normal photo already
matches the unmirrored, subject-left-on-frame's-right convention (#015). A
photo that *was* stored mirrored is a documented edge case that may misalign.
