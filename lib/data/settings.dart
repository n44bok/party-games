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
    List<String> spyWords = const [],
  }) : _prefs = prefs,
       _locale = locale,
       _haptics = haptics,
       _adsRemoved = adsRemoved,
       _spyWords = List.of(spyWords);

  static const _localeKey = 'locale';
  static const _hapticsKey = 'haptics';
  static const _adsRemovedKey = 'adsRemoved';
  static const _spyWordsKey = 'spyWords';

  /// Longest custom word kept, and how many may be saved.
  static const maxSpyWordLength = 30;
  static const maxSpyWords = 100;

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
        spyWords: prefs.getStringList(_spyWordsKey) ?? const [],
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
  final List<String> _spyWords;

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

  /// The player's own Spy words, in the order they were added.
  List<String> get spyWords => List.unmodifiable(_spyWords);

  /// Tidies a typed word: trims it, collapses inner spaces and caps its length.
  /// Returns null if nothing is left.
  static String? cleanSpyWord(String raw) {
    var word = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (word.length > maxSpyWordLength) {
      word = word.substring(0, maxSpyWordLength).trimRight();
    }
    return word.isEmpty ? null : word;
  }

  /// Adds [raw] to the player's words. Returns false (and changes nothing) if
  /// it is empty, already there (ignoring case) or the list is full.
  Future<bool> addSpyWord(String raw) async {
    final word = cleanSpyWord(raw);
    if (word == null || _spyWords.length >= maxSpyWords) return false;
    final lower = word.toLowerCase();
    if (_spyWords.any((w) => w.toLowerCase() == lower)) return false;
    _spyWords.add(word);
    notifyListeners();
    await _prefs?.setStringList(_spyWordsKey, _spyWords);
    return true;
  }

  Future<void> removeSpyWord(String word) async {
    if (!_spyWords.remove(word)) return;
    notifyListeners();
    await _prefs?.setStringList(_spyWordsKey, _spyWords);
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
