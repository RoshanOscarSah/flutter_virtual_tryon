# RELEASE.md

# flutter_virtual_tryon Release Process

## Philosophy

Releases should be predictable, stable, and reproducible.

Quality takes priority over release speed.

---

# Versioning

Use Semantic Versioning.

Examples:

0.1.0

0.2.0

0.5.0

1.0.0

Patch releases

1.0.1

Minor releases

1.1.0

Major releases

2.0.0

---

# Before Every Release

Run:

```bash
dart format .
flutter analyze
flutter test
dart pub publish --dry-run
```

Verify:

- Documentation
- Example app
- CHANGELOG
- LICENSE
- README
- API documentation

---

# Manual Verification

Test:

Android

iOS

Web

macOS

Verify:

- Camera
- Face detection
- Tracking
- Rendering
- Capture
- Debug mode

---

# Breaking Changes

Breaking API changes should be avoided.

If unavoidable:

- Clearly document
- Update Migration Guide
- Increment major version

---

# Changelog

Every release must include:

- New features
- Improvements
- Bug fixes
- Breaking changes
- Deprecations

---

# GitHub Release

Every release should include:

- Version tag
- Release notes
- Changelog
- Upgrade instructions

---

# pub.dev

Before publishing:

- Verify package score
- Verify README renders correctly
- Verify example project
- Verify screenshots/GIFs if included

---

# Emergency Patch Process

If a critical bug is discovered:

1. Create regression test.
2. Fix bug.
3. Verify tests.
4. Release patch version.
5. Update changelog.

---

# Long-Term Maintenance

Maintain compatibility with current stable Flutter and Dart releases whenever practical.

Review dependencies regularly.

Avoid unnecessary dependency upgrades.

---

# Release Checklist

☐ Code complete

☐ Tests complete

☐ Documentation complete

☐ Examples verified

☐ CHANGELOG updated

☐ README updated

☐ Performance acceptable

☐ pub publish --dry-run successful

☐ Manual testing completed

☐ Ready to publish