# CODING_STANDARDS.md

# flutter_virtual_tryon Coding Standards

These standards apply to every contribution.

Human and AI contributors must follow them consistently.

---

# General Principles

- Write clean, readable code.
- Optimize for maintainability.
- Optimize for correctness before optimization.
- Favor composition over inheritance.
- Keep modules loosely coupled.
- Keep responsibilities focused.

---

# Public API

Every public class must include Dart documentation.

Every public method must include documentation.

Every public enum must be documented.

Every public property must be documented.

Avoid breaking API changes.

---

# Naming

Use clear, descriptive names.

Avoid abbreviations.

Avoid cryptic variable names.

Public APIs should read naturally.

Example

```dart
VirtualTryOn(
    overlays: [...]
)
```

---

# Files

Keep files focused.

Prefer smaller files over very large files.

Avoid classes with multiple unrelated responsibilities.

---

# Architecture

UI must not contain tracking logic.

Tracking must not contain rendering logic.

Rendering must not contain backend-specific logic.

Backend implementations must remain isolated.

---

# Performance

Avoid unnecessary allocations.

Avoid rebuilding expensive objects every frame.

Reuse objects whenever practical.

Profile before optimizing.

---

# Error Handling

Never silently ignore errors.

Provide meaningful exceptions.

Surface actionable error messages to developers.

---

# Logging

Use structured logging.

Avoid excessive logging in release mode.

Debug logging should be optional.

---

# Testing

Every new feature requires tests.

Every bug fix requires a regression test.

Critical mathematical calculations require unit tests.

Rendering changes require visual verification.

---

# Documentation

No feature is complete without documentation.

Update documentation alongside code changes.

---

# Formatting

Use the official Dart formatter.

Maintain consistent import ordering.

Remove unused code.

Remove commented-out code before merging.

---

# Dependencies

Avoid unnecessary dependencies.

Prefer Flutter SDK functionality when appropriate.

Evaluate dependency maintenance before adoption.

---

# Git

Small, focused commits.

Meaningful commit messages.

One logical change per commit.

---

# Code Reviews

Review for:

- Correctness
- API stability
- Performance
- Readability
- Test coverage
- Documentation
- Backwards compatibility

---

# AI Contribution Rules

AI must not invent APIs that contradict ARCHITECTURE.md or API.md.

If uncertain, ask for clarification rather than making assumptions.

Do not redesign the architecture unless explicitly requested.

Follow ROADMAP.md.

Respect DECISIONS.md.

Treat PROJECT_MEMORY.md as the current project state.

Architecture consistency is more important than generating more code.
