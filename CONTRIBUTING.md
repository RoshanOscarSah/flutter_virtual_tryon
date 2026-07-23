# Contributing to flutter_virtual_tryon

Thanks for considering a contribution. This package is built to be a
long-term production dependency, so the bar for changes — especially to the
public API — is deliberately high. Please read this before opening a PR.

## Before you start

Read, in order:

1. [`doc/VISION.md`](doc/VISION.md) — what this project is trying to be
2. [`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md) — module boundaries
3. [`doc/API.md`](doc/API.md) — the frozen public surface
4. [`doc/DECISIONS.md`](doc/DECISIONS.md) — why things are the way they are
5. [`doc/CODING_STANDARDS.md`](doc/CODING_STANDARDS.md)
6. [`doc/TESTING.md`](doc/TESTING.md)

If a change you're proposing contradicts something in `ARCHITECTURE.md` or
`API.md`, open an issue to discuss it first — don't redesign silently in a
PR.

## Ground rules

- **Public API stability over new features.** Additive changes are
  preferred; breaking changes need a Migration Guide entry and a major
  version bump.
- **Never leak backend implementation details.** ML Kit, MediaPipe, Apple
  Vision, and OpenCV types must never appear in the public API
  (`doc/DECISIONS.md` #004).
- **Every public API needs Dart documentation and a test.** The analyzer
  enforces the doc requirement (`public_member_api_docs`); reviewers enforce
  the test requirement.
- **Every bug fix needs a regression test.**
- **Rendering goes through `CustomPainter`**, not widget trees
  (`doc/DECISIONS.md` #003).

## Development setup

```bash
flutter pub get
flutter analyze
flutter test
dart format --set-exit-if-changed .
```

All four must pass before you open a PR — CI runs the same checks.

## Commit style

Small, focused commits. One logical change per commit. Write commit
messages that explain *why*, not just *what*.

## Pull requests

- Keep PRs scoped to one milestone/feature where possible.
- Update `CHANGELOG.md` under `## Unreleased`.
- Update relevant docs alongside code — a feature isn't complete without
  documentation (`doc/CODING_STANDARDS.md`).
- Describe what you tested and how.

## Reporting bugs

Open a GitHub issue with:

- Flutter/Dart version (`flutter --version`)
- Platform (Android/iOS/web/macOS) and OS version
- Minimal reproduction
- Expected vs. actual behavior

## Code of Conduct

This project follows [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
