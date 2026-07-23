// INTERNAL — not exported. Picks the right backend implementation per
// platform at compile time, so google_mlkit_face_detection (imports
// dart:io — a compile error on web) and the web JS-interop backend (needs
// dart:js_interop — unavailable off web) never end up in the same build.
//
// io_backend.dart is the base/default rather than a separate "unsupported"
// stub: dart.library.io and dart.library.js_interop are exhaustive and
// mutually exclusive across real Flutter targets (every platform has
// exactly one), so a third fallback file would be unreachable dead code —
// which is what it turned out to be in the donor implementation this
// package is based on (see doc/HANDOVER.md). io_backend.dart already
// reports itself unsupported on non-Android/iOS platforms via its own
// `isSupported` getter, which is all a genuine fallback would do anyway.
export 'io_backend.dart' if (dart.library.js_interop) 'media_pipe_backend.dart';
