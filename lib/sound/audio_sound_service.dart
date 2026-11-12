import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound_service.dart';

/// Plays the bundled sounds (`assets/sounds/`) with the `audioplayers` plugin.
///
/// The sounds mix with whatever else is playing (music is not stopped) and
/// follow the phone's silent switch, so they stay quiet when the phone is set
/// to silent. Every call swallows errors: a missing audio device must never
/// break a game.
class AudioSoundService implements SoundService {
  AudioSoundService() {
    _configure();
  }

  /// Sounds exist only on phones; elsewhere (web, desktop in tests) this stays
  /// silent.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // One player per sound, so one never cuts the other off.
  final _warning = AudioPlayer();
  final _timeUp = AudioPlayer();

  Future<void> _configure() async {
    if (!isSupported) return;
    try {
      // iPhone: following the silent switch means the "ambient" audio
      // category, which already mixes with other apps' audio (audioplayers
      // refuses to combine `respectSilence` with `mixWithOthers`). Android has
      // no silent switch; there the sounds mix with the music.
      final iOS = defaultTargetPlatform == TargetPlatform.iOS;
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: iOS
              ? AudioContextConfigFocus.gain
              : AudioContextConfigFocus.mixWithOthers,
          respectSilence: iOS,
        ).build(),
      );
    } catch (e) {
      debugPrint('Could not set up audio: $e');
    }
  }

  Future<void> _play(AudioPlayer player, String asset) async {
    if (!isSupported) return;
    try {
      await player.stop(); // restart if it is still sounding
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Could not play $asset: $e');
    }
  }

  @override
  void playWarning() => _play(_warning, 'sounds/warning.wav');

  @override
  void playTimeUp() => _play(_timeUp, 'sounds/time_up.wav');
}
