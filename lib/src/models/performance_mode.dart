/// Trade-off between detection speed and tracking quality.
///
/// Backends map each mode onto their own tuning knobs (frame throttling,
/// model complexity, landmark refinement). The mapping is an implementation
/// detail; the relative ordering — [fast] cheapest, [highAccuracy] best —
/// is the contract.
enum PerformanceMode {
  /// Prioritize frame rate and battery over landmark precision.
  fast,

  /// Balanced speed and quality. The default.
  balanced,

  /// Prioritize landmark precision over speed. May reduce frame rate on
  /// low-end devices.
  highAccuracy,
}
