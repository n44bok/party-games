import 'package:flutter/widgets.dart';

/// What the UI needs from the ad system. The real implementation talks to
/// AdMob ([GoogleAdService]); [NoAdService] shows nothing and is used in tests
/// and on platforms without ads.
abstract class AdService {
  /// A banner, or an empty widget when there is no ad to show.
  Widget buildBanner();

  /// Call when a round has been played. May show a full-screen ad; never
  /// blocks the game, and does nothing if no ad is ready.
  void onRoundFinished();
}

class NoAdService implements AdService {
  const NoAdService();

  @override
  Widget buildBanner() => const SizedBox.shrink();

  @override
  void onRoundFinished() {}
}

/// Decides when a full-screen ad is due: once every [every] rounds.
///
/// Kept separate from the ad SDK so the frequency rule can be tested, and so
/// that it can be tuned in one place.
class InterstitialPacer {
  InterstitialPacer({this.every = 6}) : assert(every > 0);

  final int every;
  int _rounds = 0;

  /// Registers a finished round; returns true if an ad is due now.
  bool onRound() {
    _rounds++;
    return _rounds % every == 0;
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
