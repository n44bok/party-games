import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/settings.dart';
import 'ad_service.dart';

/// Ad unit ids.
///
/// These are Google's official TEST units: they always return a clearly
/// labelled test ad and are safe to click. Replace them with the real units
/// from the AdMob console before release (and never click your own live ads).
class AdUnits {
  const AdUnits._();

  static String get banner => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ca-app-pub-3940256099942544/6300978111',
    TargetPlatform.iOS => 'ca-app-pub-3940256099942544/2934735716',
    _ => '',
  };

  static String get interstitial => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ca-app-pub-3940256099942544/1033173712',
    TargetPlatform.iOS => 'ca-app-pub-3940256099942544/4411468910',
    _ => '',
  };
}

/// AdMob ads: a banner on the home screen and a full-screen ad every few
/// rounds. Nothing is shown once [SettingsController.adsRemoved] is set.
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
  void onRoundFinished() {
    if (!isSupported || _settings.adsRemoved) return;
    if (!_pacer.onRound()) return;

    final ad = _interstitial;
    if (ad == null) {
      // Not ready: skip this one rather than make the player wait.
      _loadInterstitial();
      return;
    }
    _interstitial = null;
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

/// A standard 320x50 banner. Takes no space until an ad has loaded, so a
/// failed or missing ad leaves no gap.
class _BannerView extends StatefulWidget {
  const _BannerView({required this.settings});

  final SettingsController settings;

  @override
  State<_BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<_BannerView> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    _loadIfAllowed();
  }

  void _onSettingsChanged() {
    if (widget.settings.adsRemoved) {
      _discard();
    } else {
      _loadIfAllowed();
    }
  }

  void _loadIfAllowed() {
    if (widget.settings.adsRemoved || _ad != null) return;
    final ad = BannerAd(
      adUnitId: AdUnits.banner,
      size: AdSize.banner,
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
    final ad = _ad;
    if (ad == null || widget.settings.adsRemoved) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
