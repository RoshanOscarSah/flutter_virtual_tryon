/// The engine's current relationship to a face.
///
/// Exposed via `VirtualTryOnController.trackingState`. Individual
/// measurements are delivered as `TrackingData`, which only exists while a
/// face is actually tracked — so `TrackingData` itself carries no state
/// field.
enum TrackingState {
  /// The backend is loading models / opening the camera. No face data yet.
  initializing,

  /// A face is currently being tracked; `onFaceUpdated` is streaming.
  tracking,

  /// Tracking was established at least once but the face has been lost.
  lost,
}
