import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// What the "Song backwards" game needs from the phone's audio: recording the
/// microphone and playing WAV recordings. The real implementation is
/// [RecordVoiceService]; [NoVoiceService] does nothing (tests and platforms
/// without a microphone).
abstract class VoiceService {
  /// Asks for the microphone if needed; `false` when it is not allowed.
  Future<bool> ensurePermission();

  /// Starts recording. Throws if the microphone cannot be used.
  Future<void> startRecording();

  /// Stops and returns the recording as WAV bytes, or `null` if there is none.
  Future<Uint8List?> stopRecording();

  /// Plays [wav] and completes when it has finished (or was stopped).
  Future<void> play(Uint8List wav);

  Future<void> stopPlaying();

  void dispose();
}

class NoVoiceService implements VoiceService {
  const NoVoiceService();

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> startRecording() async {}

  @override
  Future<Uint8List?> stopRecording() async => null;

  @override
  Future<void> play(Uint8List wav) async {}

  @override
  Future<void> stopPlaying() async {}

  @override
  void dispose() {}
}

/// Makes the [VoiceService] available to descendants.
class VoiceScope extends InheritedWidget {
  const VoiceScope({super.key, required this.service, required super.child});

  final VoiceService service;

  /// The service without subscribing to changes. Does nothing when there is
  /// no scope.
  static VoiceService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<VoiceScope>()?.service ??
      const NoVoiceService();

  @override
  bool updateShouldNotify(VoiceScope oldWidget) => service != oldWidget.service;
}
