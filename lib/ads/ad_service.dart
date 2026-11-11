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

  /// Call when a round has been played. May show a full-screen ad; never
  /// blocks the game, and does nothing if no ad is ready.
  void onRoundFinished();
}

class NoAdService implements AdService {
  const NoAdService();

  @override
  Widget buildBanner() => const SizedBox.shrink();

  @override
  void onGameStarted() {}

  @override
  void onRoundFinished() {}
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

  /// Falls back to no ads when there is no scope, so a missing one can never
  /// crash the UI.
  static AdService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdScope>()?.service ??
      const NoAdService();

  @override
  bool updateShouldNotify(AdScope oldWidget) => service != oldWidget.service;
}
