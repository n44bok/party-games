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
    bool adsRemoved = false,
  }) : _prefs = prefs,
       _locale = locale,
       _haptics = haptics,
       _adsRemoved = adsRemoved;

  static const _localeKey = 'locale';
  static const _hapticsKey = 'haptics';
  static const _adsRemovedKey = 'adsRemoved';

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
        adsRemoved: prefs.getBool(_adsRemovedKey) ?? false,
      );
    } catch (e) {
      debugPrint('Could not load settings, using defaults: $e');
      return SettingsController();
    }
  }

  final SharedPreferences? _prefs;

  Locale? _locale;
  bool _haptics;
  bool _adsRemoved;

  /// `null` means "follow the system language".
  Locale? get locale => _locale;

  /// Whether a light vibration accompanies card changes.
  bool get haptics => _haptics;

  /// True once Premium has been bought: no ad is requested or shown.
  bool get adsRemoved => _adsRemoved;

  Future<void> setAdsRemoved(bool value) async {
    if (value == _adsRemoved) return;
    _adsRemoved = value;
    notifyListeners();
    await _prefs?.setBool(_adsRemovedKey, value);
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

  /// Rebuilds the caller when any setting changes.
  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in the widget tree');
    return scope!.notifier!;
  }
}
