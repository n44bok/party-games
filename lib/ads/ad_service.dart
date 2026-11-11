import 'package:flutter/widgets.dart';

/// What the UI needs from the ad system. The real implementation talks to
/// AdMob ([GoogleAdService]); [NoAdService] shows nothing and is used in tests
/// and on platforms without ads.
abstract class AdService {
  /// A banner, or an empty widget when there is no ad to show.
  Widget buildBanner();

  /// Call when a new game starts (a game screen opens). Resets the per-game
  /// ad budget.
  void onGameStarted();

  /// Starts loading a full-screen ad so it is ready when needed. Call
  /// ahead of [showStartInterstitial] (e.g. when a setup screen opens).
  void prepareInterstitial();

  /// Shows a full-screen ad right now if one is ready. Never waits: if none
  /// is ready, nothing is shown. For games that show their ad once, when
  /// they start (rather than after a number of rounds).
  void showStartInterstitial();

  /// Call when a round has been played. May show a full-screen ad; never
  /// blocks the game, and does nothing if no ad is ready.
  void onRoundFinished();

  /// Whether people must be able to change their ad privacy choice (they are
  /// somewhere consent is required). Settings shows an entry if so.
  Future<bool> privacyOptionsRequired();

  /// Opens the form where people can change their ad privacy choice.
  Future<void> showPrivacyOptions();
}

class NoAdService implements AdService {
  const NoAdService();

  @override
  Widget buildBanner() => const SizedBox.shrink();

  @override
  void onGameStarted() {}

  @override
  void prepareInterstitial() {}

  @override
  void showStartInterstitial() {}

  @override
  void onRoundFinished() {}

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

/// Decides when a full-screen ad is due: at most once per game, after
/// [after] rounds.
///
/// Kept separate from the ad SDK so the rule can be tested and tuned in one
/// place. An ad that is due stays due until [markShown] is called, so if it
/// was not loaded yet at round [after] it can still appear a round or two
/// later, but never more than once in the same game.
class InterstitialPacer {
  InterstitialPacer({this.after = 6}) : assert(after > 0);

  final int after;
  int _rounds = 0;
  bool _shown = false;

  /// Registers a finished round; returns true while an ad is due.
  bool onRound() {
    _rounds++;
    return !_shown && _rounds >= after;
  }

  /// Records that the ad was actually shown: no more in this game.
  void markShown() => _shown = true;

  /// A new game begins: start counting again.
  void reset() {
    _rounds = 0;
    _shown = false;
  }
}

/// Makes the [AdService] available to descendants.
class AdScope extends InheritedWidget {
  const AdScope({super.key, required this.service, required super.child});

  final AdService service;

  /// The service without subscribing to changes: for use in callbacks that
  /// run outside of `build`.
  static AdService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AdScope>()?.service ??
      const NoAdService();

  /// Falls back to no ads when there is no scope, so a missing one can never
  /// crash the UI.
  static AdService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdScope>()?.service ??
      const NoAdService();

  @override
  bool updateShouldNotify(AdScope oldWidget) => service != oldWidget.service;
}
