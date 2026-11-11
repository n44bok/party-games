import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'voice_service.dart';

/// Records the microphone with the `record` plugin (as 16-bit mono WAV, which
/// is easy to reverse) and plays recordings with `audioplayers`.
///
/// Recordings live in a temporary folder and are deleted right after they are
/// read.
class RecordVoiceService implements VoiceService {
  RecordVoiceService();

  /// Only phones have what this needs.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  Directory? _dir;
  Completer<void>? _playing;
  StreamSubscription<void>? _completeSub;
  var _fileCounter = 0;

  Future<Directory> _folder() async =>
      _dir ??= await Directory.systemTemp.createTemp('song_backwards');

  @override
  Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Microphone permission check failed: $e');
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    await stopPlaying();
    final path = '${(await _folder()).path}/rec${_fileCounter++}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
  }

  @override
  Future<Uint8List?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (path == null) return null;
      final file = File(path);
      final bytes = await file.readAsBytes();
      unawaited(file.delete().catchError((_) => file));
      return bytes;
    } catch (e) {
      debugPrint('Could not finish the recording: $e');
      return null;
    }
  }

  @override
  Future<void> play(Uint8List wav) async {
    await stopPlaying();
    final done = _playing = Completer<void>();
    try {
      final file = File('${(await _folder()).path}/play${_fileCounter++}.wav');
      await file.writeAsBytes(wav, flush: true);
      await _completeSub?.cancel();
      _completeSub = _player.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      });
      // Loud and clear even if the phone is on silent: the game is about
      // listening.
      await _player.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.gain,
          respectSilence: false,
        ).build(),
      );
      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Could not play the recording: $e');
      if (!done.isCompleted) done.complete();
    }
    await done.future;
  }

  @override
  Future<void> stopPlaying() async {
    final playing = _playing;
    if (playing != null && !playing.isCompleted) playing.complete();
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _player.dispose();
    _recorder.dispose();
    _dir?.delete(recursive: true).catchError((_) => _dir!);
  }
}
