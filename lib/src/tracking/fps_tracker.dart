// INTERNAL — not exported. Measures instantaneous frame rate across calls,
// for backends to populate TrackingData.fps/timestamp with.

/// Tracks the time between successive [tick]s to report an instantaneous
/// frames-per-second figure.
///
/// Deliberately instantaneous (1 / delta-since-last-tick) rather than a
/// windowed average — simpler, and good enough for a debug readout; a
/// smoothed FPS counter would need its own tunable window, which isn't
/// worth the API surface for a diagnostic-only value.
class FpsTracker {
  DateTime? _lastTick;

  /// Records one frame at [now] and returns the fps computed against the
  /// previous [tick] — null on the very first call (no prior sample to
  /// measure against) or if [now] didn't advance (clock resolution/replay).
  double? tick(DateTime now) {
    final last = _lastTick;
    _lastTick = now;
    if (last == null) return null;
    final elapsedMicros = now.difference(last).inMicroseconds;
    if (elapsedMicros <= 0) return null;
    return Duration.microsecondsPerSecond / elapsedMicros;
  }
}
