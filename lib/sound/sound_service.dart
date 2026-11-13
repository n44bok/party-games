import 'package:flutter/widgets.dart';

/// The short sound signals of the game. The real implementation plays audio
/// files ([AudioSoundService]); [NoSoundService] is silent and is used in tests
/// and wherever sound is not available.
///
/// Playing never throws and never waits for the sound to finish.
abstract class SoundService {
  /// Quick rising beeps: "hurry up" (time is nearly out).
  void playWarning();

  /// A longer falling buzzer: "stop" (time is out).
  void playTimeUp();

  /// Mafia: soft night ambience (crickets, a low drone) on a loop, until
  /// [stopNightAmbience].
  void startNightAmbience();
  void stopNightAmbience();

  /// Mafia: a gentle chime for the morning.
  void playMorning();
}

class NoSoundService implements SoundService {
  const NoSoundService();

  @override
  void playWarning() {}

  @override
  void playTimeUp() {}

  @override
  void startNightAmbience() {}

  @override
  void stopNightAmbience() {}

  @override
  void playMorning() {}
}

/// Makes the [SoundService] available to descendants.
class SoundScope extends InheritedWidget {
  const SoundScope({super.key, required this.service, required super.child});

  final SoundService service;

  /// The service without subscribing to changes: for callbacks that run
  /// outside of `build`. Silent when there is no scope, so a missing one can
  /// never crash the UI.
  static SoundService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SoundScope>()?.service ??
      const NoSoundService();

  @override
  bool updateShouldNotify(SoundScope oldWidget) => service != oldWidget.service;
}
