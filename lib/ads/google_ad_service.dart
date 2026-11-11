import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/settings.dart';
import 'ad_service.dart';

/// Ad unit ids.
///
/// Release builds (the ones that go to the stores) use our real AdMob units.
/// Debug and profile builds use Google's official TEST units, which always
/// return a clearly labelled test ad and are safe to click: never click live
/// ads on your own phone, AdMob treats that as invalid traffic.
class AdUnits {
  const AdUnits._();

  static bool get _live => kReleaseMode;

  static String get banner => switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      _live
          ? 'ca-app-pub-6734526134116766/2317548202'
          : 'ca-app-pub-3940256099942544/6300978111',
    TargetPlatform.iOS =>
      _live
          ? 'ca-app-pub-6734526134116766/8292909556'
          : 'ca-app-pub-3940256099942544/2934735716',
    _ => '',
  };

  static String get interstitial => switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      _live
          ? 'ca-app-pub-6734526134116766/5462586297'
          : 'ca-app-pub-3940256099942544/1033173712',
    TargetPlatform.iOS =>
      _live
          ? 'ca-app-pub-6734526134116766/5666746219'
          : 'ca-app-pub-3940256099942544/4411468910',
    _ => '',
  };
}

/// AdMob ads: banners on the home and setup screens and one full-screen ad per game,
/// after a few rounds. Nothing is shown once [SettingsController.adsRemoved] is set.
// TODO(ads): rewarded ads to unlock premium categories.
// TODO(ads): ask for consent (UMP, and ATT on iOS) before serving real ads.
class GoogleAdService implements AdService {
  GoogleAdService(this._settings, {InterstitialPacer? pacer})
    : _pacer = pacer ?? InterstitialPacer();

  final SettingsController _settings;
  final InterstitialPacer _pacer;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  /// Ads exist only on phones; elsewhere (web, desktop) this stays inert.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Starts the SDK and preloads the first full-screen ad. Never throws: a
  /// failure here must not stop the app from starting.
  Future<void> initialize() async {
    if (!isSupported) return;
    try {
      await MobileAds.instance.initialize();
      _loadInterstitial();
    } catch (e) {
      debugPrint('Could not start the ads SDK: $e');
    }
  }

  void _loadInterstitial() {
    if (!isSupported || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdUnits.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _loadingInterstitial = false;
        },
      ),
    );
  }

  @override
  void onGameStarted() {
    _pacer.reset();
    _loadInterstitial(); // have one ready by the time round 6 comes
  }

  @override
  void prepareInterstitial() {
    if (_settings.adsRemoved) return;
    _loadInterstitial();
  }

  @override
  void showStartInterstitial() {
    if (!isSupported || _settings.adsRemoved) return;
    final ad = _interstitial;
    if (ad == null) {
      // Not ready: never hold up the game for an ad, and do not show it
      // later either (this one is for the start only).
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _show(ad);
  }

  @override
  void onRoundFinished() {
    if (!isSupported || _settings.adsRemoved) return;
    if (!_pacer.onRound()) return;

    final ad = _interstitial;
    if (ad == null) {
      // Not ready: never make the player wait. The ad stays due, so it can
      // still appear on a later round of this game once it has loaded.
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _pacer.markShown();
    _show(ad);
  }

  /// Shows [ad] and loads the next one when it closes.
  void _show(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  @override
  Widget buildBanner() =>
      isSupported ? _BannerView(settings: _settings) : const SizedBox.shrink();
}

/// An anchored adaptive banner: AdMob picks the height for the width it is
/// given, so it spans the available width. Takes no space until an ad has
/// loaded, so a failed or missing ad leaves no gap.
class _BannerView extends StatefulWidget {
  const _BannerView({required this.settings});

  final SettingsController settings;

  @override
  State<_BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<_BannerView> {
  BannerAd? _ad;
  bool _loading = false;
  int? _width;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (widget.settings.adsRemoved) {
      _discard();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load(int width) async {
    if (widget.settings.adsRemoved || _ad != null || _loading) return;
    _loading = true;
    _width = width;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null || widget.settings.adsRemoved) {
      _loading = false;
      return;
    }
    final ad = BannerAd(
      adUnitId: AdUnits.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (failed, error) {
          debugPrint('Banner failed to load: $error');
          failed.dispose();
          if (_ad == failed) _ad = null;
          if (mounted) setState(() {});
        },
      ),
    );
    _ad = ad;
    _loading = false;
    ad.load();
  }

  void _discard() {
    _ad?.dispose();
    _ad = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settings.adsRemoved) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.truncate()
            : MediaQuery.sizeOf(context).width.truncate();
        if (_ad == null && !_loading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _load(width);
          });
        } else if (_ad != null && _width != width) {
          // Width changed (rotation): load a banner sized for it.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ad?.dispose();
            _ad = null;
            _load(width);
          });
        }
        final ad = _ad;
        if (ad == null) return const SizedBox.shrink();
        return SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        );
      },
    );
  }
}
