// Named parameters cannot be private, so the private fields are assigned in
// the initializer list instead of with initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences, persisted with shared_preferences.
///
/// Listen to it (it is a [ChangeNotifier]) to react to changes; the app
/// provides it to the tree through [SettingsScope].
class SettingsController extends ChangeNotifier {
  SettingsController({
    SharedPreferences? prefs,
    Locale? locale,
    bool haptics = true,
    DateTime? premiumUntil,
    bool timeWarning = true,
    DateTime Function()? clock,
  }) : _prefs = prefs,
       _locale = locale,
       _haptics = haptics,
       _premiumUntil = premiumUntil,
       _timeWarning = timeWarning,
       _clock = clock ?? DateTime.now {
    _premiumActive = _isPremiumNow;
  }

  static const _localeKey = 'locale';
  static const _hapticsKey = 'haptics';
  static const _premiumUntilKey = 'premiumUntil';
  static const _timeWarningKey = 'timeWarning';

  /// Longest own Spy word.
  static const maxSpyWordLength = 30;

  /// Reads the saved preferences. Falls back to defaults if storage fails, so
  /// a broken preferences file never prevents the app from starting.
  static Future<SettingsController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localeKey);
      return SettingsController(
        prefs: prefs,
        locale: code == null ? null : Locale(code),
        haptics: prefs.getBool(_hapticsKey) ?? true,
        premiumUntil: _readDate(prefs.getInt(_premiumUntilKey)),
        timeWarning: prefs.getBool(_timeWarningKey) ?? true,
      );
    } catch (e) {
      debugPrint('Could not load settings, using defaults: $e');
      return SettingsController();
    }
  }

  static DateTime? _readDate(int? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);

  final SharedPreferences? _prefs;
  final DateTime Function() _clock;

  Locale? _locale;
  bool _haptics;
  DateTime? _premiumUntil;
  late bool _premiumActive;
  bool _timeWarning;

  /// `null` means "follow the system language".
  Locale? get locale => _locale;

  /// Whether a light vibration accompanies card changes.
  bool get haptics => _haptics;

  /// How long Premium runs, or `null` if it never was bought.
  DateTime? get premiumUntil => _premiumUntil;

  bool get _isPremiumNow {
    final until = _premiumUntil;
    return until != null && until.isAfter(_clock());
  }

  /// True while Premium is active: no ad is requested or shown.
  bool get adsRemoved => _isPremiumNow;

  /// The store confirmed Premium; it runs until [until] (later than what was
  /// known, never earlier).
  Future<void> grantPremium(DateTime until) async {
    final current = _premiumUntil;
    if (current != null && !until.isAfter(current)) return;
    _premiumUntil = until;
    _premiumActive = _isPremiumNow;
    notifyListeners();
    await _prefs?.setInt(_premiumUntilKey, until.millisecondsSinceEpoch);
  }

  /// Call when the app comes back to the foreground: Premium may have run out
  /// meanwhile, and then the ads must come back.
  void recheckPremium() {
    final now = _isPremiumNow;
    if (now == _premiumActive) return;
    _premiumActive = now;
    notifyListeners();
  }

  /// Whether Spy warns the players shortly before the time runs out.
  bool get timeWarning => _timeWarning;

  Future<void> setTimeWarning(bool value) async {
    if (value == _timeWarning) return;
    _timeWarning = value;
    notifyListeners();
    await _prefs?.setBool(_timeWarningKey, value);
  }

  /// Tidies a typed word: trims it, collapses inner spaces and caps its length.
  /// Returns null if nothing is left.
  static String? cleanSpyWord(String raw) {
    var word = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (word.length > maxSpyWordLength) {
      word = word.substring(0, maxSpyWordLength).trimRight();
    }
    return word.isEmpty ? null : word;
  }

  Future<void> setLocale(Locale? value) async {
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
    if (value == null) {
      await _prefs?.remove(_localeKey);
    } else {
      await _prefs?.setString(_localeKey, value.languageCode);
    }
  }

  Future<void> setHaptics(bool value) async {
    if (value == _haptics) return;
    _haptics = value;
    notifyListeners();
    await _prefs?.setBool(_hapticsKey, value);
  }
}

/// Makes the [SettingsController] available to descendants.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController settings,
    required super.child,
  }) : super(notifier: settings);

  /// The settings without subscribing to changes, for callbacks that run
  /// outside of `build`.
  static SettingsController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  /// Rebuilds the caller when any setting changes.
  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in the widget tree');
    return scope!.notifier!;
  }
}
