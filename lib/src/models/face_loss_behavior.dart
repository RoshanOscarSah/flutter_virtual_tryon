/// What the renderer does with overlays when the tracked face is lost.
///
/// This is a sealed hierarchy rather than an enum so variants can carry
/// configuration (see [FadeFaceLossBehavior.duration]) and switches stay
/// exhaustive. Regardless of the chosen behavior, `onFaceLost` always
/// fires — [FaceLossBehavior.custom] is for apps that want *only* the
/// callback, with no built-in visual reaction.
sealed class FaceLossBehavior {
  const FaceLossBehavior._();

  /// Hide all overlays immediately. The default.
  const factory FaceLossBehavior.hide() = HideFaceLossBehavior;

  /// Keep rendering overlays at the last known tracking position.
  const factory FaceLossBehavior.freeze() = FreezeFaceLossBehavior;

  /// Fade overlays out over [FadeFaceLossBehavior.duration], holding the
  /// last known position while fading.
  const factory FaceLossBehavior.fade({Duration duration}) =
      FadeFaceLossBehavior;

  /// Take no built-in visual action — overlays keep rendering at the last
  /// known position, exactly like [freeze], but named to signal that the
  /// app drives its own reaction from `onFaceLost`.
  const factory FaceLossBehavior.custom() = CustomFaceLossBehavior;
}

/// See [FaceLossBehavior.hide].
final class HideFaceLossBehavior extends FaceLossBehavior {
  /// Creates the hide-on-loss behavior.
  const HideFaceLossBehavior() : super._();
}

/// See [FaceLossBehavior.freeze].
final class FreezeFaceLossBehavior extends FaceLossBehavior {
  /// Creates the freeze-on-loss behavior.
  const FreezeFaceLossBehavior() : super._();
}

/// See [FaceLossBehavior.fade].
final class FadeFaceLossBehavior extends FaceLossBehavior {
  /// Creates the fade-on-loss behavior.
  const FadeFaceLossBehavior(
      {this.duration = const Duration(milliseconds: 300)})
      : super._();

  /// How long the fade-out takes from full opacity to invisible.
  final Duration duration;
}

/// See [FaceLossBehavior.custom].
final class CustomFaceLossBehavior extends FaceLossBehavior {
  /// Creates the no-built-in-action behavior.
  const CustomFaceLossBehavior() : super._();
}
