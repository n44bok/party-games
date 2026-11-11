import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../ads/ad_service.dart';
import '../charades/charades_deck.dart' show charadesWinners;
import '../data/settings.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../reverse/voice_service.dart';
import '../reverse/wav_reverse.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';
import '../widgets/load_error.dart';
import '../widgets/round_parts.dart';

enum _Phase {
  ready,
  singing,
  listening,
  imitating,
  guessing,
  steal,
  reveal,
  result,
}

/// The whole "Song backwards" team game on one screen.
///
/// On a team's turn:
/// 1. one of its players sings a short part of a song into the microphone;
/// 2. a teammate hears the recording played backwards and sings back what
///    they heard;
/// 3. the app plays that attempt backwards and the team guesses the song;
/// 4. if it cannot, the other teams get the chance one after another;
/// 5. the original is played, and whoever guessed has scored a point.
class ReverseSongScreen extends StatefulWidget {
  const ReverseSongScreen({
    super.key,
    required this.playerNames,
    required this.rounds,
  });

  /// Team names in turn order (two at least).
  final List<String> playerNames;

  /// How many times each team has the turn.
  final int rounds;

  @override
  State<ReverseSongScreen> createState() => _ReverseSongScreenState();
}

class _ReverseSongScreenState extends State<ReverseSongScreen> {
  /// Players stop their own recordings; this only keeps a forgotten one from
  /// filling the memory.
  static const _maxSeconds = 120;

  _Phase _phase = _Phase.ready;
  late VoiceService _voice;
  bool _started = false;

  late List<int> _scores = List.filled(_players, 0);
  int _turn = 0;

  Uint8List? _original;
  Uint8List? _originalReversed;
  Uint8List? _imitationReversed;

  bool _recording = false;
  bool _stopping = false;
  int _elapsed = 0;
  Timer? _ticker;
  bool _playing = false;

  /// The Strings key of a problem to show instead of the phase (denied
  /// microphone, failed recording), if any.
  String? _problem;

  int get _players => widget.playerNames.length;

  /// The team whose turn it is.
  int get _team => _turn % _players;

  /// How many of the other teams have already had their chance to guess.
  int _stealStep = 0;

  /// The other team that is guessing now (after the turn's own team).
  int get _stealTeam => (_team + 1 + _stealStep) % _players;

  int get _round => _turn ~/ _players + 1;
  String _name(int i) => widget.playerNames[i];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _voice = VoiceScope.read(context);
      // The game's only ad: once, as it starts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AdScope.read(context).showStartInterstitial();
      });
    }
  }

  void _haptic() {
    if (SettingsScope.read(context).haptics) HapticFeedback.selectionClick();
  }

  // ------------------------------------------------------------- recording

  Future<void> _startRecording() async {
    _haptic();
    setState(() => _problem = null);
    try {
      if (!await _voice.ensurePermission()) {
        if (mounted) setState(() => _problem = 'reverse_mic_denied');
        return;
      }
      await _voice.startRecording();
    } catch (_) {
      if (mounted) setState(() => _problem = 'reverse_error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _elapsed = 0;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed++);
      if (_elapsed >= _maxSeconds) _stopRecording();
    });
  }

  /// Stops recording and returns the recording backwards, or `null` after
  /// showing a problem.
  Future<({Uint8List original, Uint8List reversed})?> _finishRecording() async {
    _ticker?.cancel();
    final bytes = await _voice.stopRecording();
    if (!mounted) return null;
    setState(() => _recording = false);
    if (bytes == null) {
      setState(() => _problem = 'reverse_error');
      return null;
    }
    try {
      return (original: bytes, reversed: reverseWav(bytes));
    } on FormatException {
      setState(() => _problem = 'reverse_error');
      return null;
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording || _stopping) return;
    _stopping = true;
    final done = await _finishRecording();
    _stopping = false;
    if (done == null || !mounted) return;
    setState(() {
      if (_phase == _Phase.singing) {
        _original = done.original;
        _originalReversed = done.reversed;
        _phase = _Phase.listening;
      } else {
        _imitationReversed = done.reversed;
        _phase = _Phase.guessing;
      }
    });
  }

  // -------------------------------------------------------------- playback

  Future<void> _togglePlay(Uint8List? audio) async {
    if (audio == null) return;
    if (_playing) {
      await _voice.stopPlaying();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    await _voice.play(audio);
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _go(_Phase phase) async {
    await _voice.stopPlaying();
    if (!mounted) return;
    setState(() {
      _playing = false;
      _problem = null;
      _phase = phase;
    });
  }

  /// [team] guessed the song: a point for them, then the original.
  void _award(int team) {
    _haptic();
    _scores[team]++;
    _go(_Phase.reveal);
  }

  /// The turn's own team cannot guess: the next team gets its chance.
  void _passOn() {
    _stealStep = 0;
    _go(_Phase.steal);
  }

  /// The team that had its chance did not guess it either.
  void _stealFailed() {
    if (_stealStep + 1 >= _players - 1) {
      _go(_Phase.reveal); // nobody is left to try
    } else {
      _voice.stopPlaying();
      setState(() {
        _stealStep++;
        _playing = false;
      });
    }
  }

  /// After the original: the next team's turn, or the results.
  void _nextTurn() {
    if (_turn + 1 >= _players * widget.rounds) {
      _go(_Phase.result);
    } else {
      _turn++;
      _stealStep = 0;
      _original = _originalReversed = _imitationReversed = null;
      _go(_Phase.ready);
    }
  }

  void _playAgain() {
    _scores = List.filled(_players, 0);
    _turn = 0;
    _stealStep = 0;
    _original = _originalReversed = _imitationReversed = null;
    _go(_Phase.ready);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) _voice.stopRecording();
    _voice.stopPlaying();
    super.dispose();
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          s.modeName(GameMode.reverseSong),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
        ),
      ),
      body: GradientBackground(
        dark: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _problem != null
                ? LoadError(
                    message: s[_problem!],
                    retryLabel: s['reverse_try_again'],
                    onRetry: () => setState(() => _problem = null),
                  )
                : switch (_phase) {
                    _Phase.ready => _buildReady(s),
                    _Phase.singing => _buildRecord(
                      s,
                      title: s.format('reverse_sing_title', {
                        'name': _name(_team),
                      }),
                      hint: s['reverse_sing_hint'],
                    ),
                    _Phase.listening => _buildStep(
                      s,
                      title: s.format('reverse_listen_title', {
                        'name': _name(_team),
                      }),
                      hint: s['reverse_listen_hint'],
                      audio: _originalReversed,
                      buttonLabel: s['reverse_sing_back'],
                      onNext: () => _go(_Phase.imitating),
                    ),
                    _Phase.imitating => _buildRecord(
                      s,
                      title: s['reverse_imitate_title'],
                      hint: s['reverse_imitate_hint'],
                    ),
                    _Phase.guessing => _buildGuess(
                      s,
                      team: _team,
                      title: s.format('reverse_guess_title', {
                        'name': _name(_team),
                      }),
                      hint: s['reverse_guess_hint'],
                      onGuessed: () => _award(_team),
                      onFailed: _passOn,
                      failedLabel: s['reverse_pass_on'],
                    ),
                    _Phase.steal => _buildGuess(
                      s,
                      team: _stealTeam,
                      title: s.format('reverse_steal_title', {
                        'name': _name(_stealTeam),
                      }),
                      hint: s['reverse_steal_hint'],
                      onGuessed: () => _award(_stealTeam),
                      onFailed: _stealFailed,
                      failedLabel: s['reverse_no'],
                    ),
                    _Phase.reveal => _buildReveal(s),
                    _Phase.result => _buildResult(s),
                  },
          ),
        ),
      ),
    );
  }

  Widget _buildReady(Strings s) {
    return Column(
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            s.format('charades_round', {'n': _round, 'total': widget.rounds}),
            key: const Key('reverseRound'),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Expanded(
          child: Center(
            child: PassCard(
              key: ValueKey('ready$_turn'),
              name: _name(_team),
              label: s['spy_pass_to'],
              nameKey: const Key('reverseTeam'),
            ),
          ),
        ),
        GradientButton(
          label: s['charades_ready'],
          icon: Icons.play_arrow_rounded,
          height: 60,
          onPressed: () => _go(_Phase.singing),
        ),
      ],
    );
  }

  /// A heading, a hint and (while recording) the progress.
  Widget _heading(String title, String hint, {Key? titleKey}) {
    return Column(
      children: [
        Text(
          title,
          key: titleKey ?? const Key('reverseTitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildRecord(
    Strings s, {
    required String title,
    required String hint,
  }) {
    return Column(
      children: [
        _heading(title, hint),
        Expanded(
          child: Center(
            child: _recording
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mic_rounded,
                        size: 96,
                        color: Color(0xFFFF6A6A),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s['reverse_recording'],
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        TimerDial.format(_elapsed),
                        key: const Key('reverseElapsed'),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                : Icon(
                    Icons.mic_none_rounded,
                    size: 96,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
          ),
        ),
        GradientButton(
          key: const Key('reverseRecordButton'),
          label: _recording ? s['reverse_stop'] : s['reverse_record'],
          icon: _recording ? Icons.stop_rounded : Icons.mic_rounded,
          height: 60,
          onPressed: _recording ? _stopRecording : _startRecording,
        ),
      ],
    );
  }

  /// A step where a recording can be played as often as wanted.
  Widget _buildStep(
    Strings s, {
    required String title,
    required String hint,
    required Uint8List? audio,
    required String buttonLabel,
    required VoidCallback onNext,
  }) {
    return Column(
      children: [
        _heading(title, hint),
        Expanded(
          child: Center(
            child: _PlayButton(
              playing: _playing,
              playLabel: s['reverse_play'],
              stopLabel: s['reverse_stop'],
              onTap: () => _togglePlay(audio),
            ),
          ),
        ),
        GradientButton(label: buttonLabel, height: 60, onPressed: onNext),
      ],
    );
  }

  /// A team listens to the imitation as often as it likes, then says
  /// whether it knows the song.
  Widget _buildGuess(
    Strings s, {
    required int team,
    required String title,
    required String hint,
    required VoidCallback onGuessed,
    required VoidCallback onFailed,
    required String failedLabel,
  }) {
    return Column(
      key: ValueKey('guess$team$_phase'),
      children: [
        _heading(title, hint),
        Expanded(
          child: Center(
            child: _PlayButton(
              playing: _playing,
              playLabel: s['reverse_play'],
              stopLabel: s['reverse_stop'],
              onTap: () => _togglePlay(_imitationReversed),
            ),
          ),
        ),
        GradientButton(
          key: const Key('reverseGuessed'),
          label: s['reverse_yes'],
          icon: Icons.check_rounded,
          height: 60,
          onPressed: onGuessed,
        ),
        const SizedBox(height: 12),
        GlassButton(
          key: const Key('reverseFailed'),
          label: failedLabel,
          icon: Icons.close_rounded,
          onPressed: onFailed,
        ),
      ],
    );
  }

  Widget _buildReveal(Strings s) {
    return Column(
      children: [
        _heading(s['reverse_original_title'], s['reverse_original_hint']),
        Expanded(
          child: Center(
            child: _PlayButton(
              playing: _playing,
              playLabel: s['reverse_play'],
              stopLabel: s['reverse_stop'],
              onTap: () => _togglePlay(_original),
            ),
          ),
        ),
        GradientButton(
          label: _turn + 1 >= _players * widget.rounds
              ? s['charades_see_results']
              : s['reverse_next_team'],
          height: 60,
          onPressed: _nextTurn,
        ),
      ],
    );
  }

  Widget _buildResult(Strings s) {
    final winners = charadesWinners(_scores);
    return Column(
      children: [
        Expanded(
          child: ResultBoard(
            title: winners.length == 1
                ? s.format('charades_winner', {'name': _name(winners.single)})
                : s['charades_tie'],
            titleKey: const Key('reverseWinner'),
            subtitle: s['charades_scores'],
            names: widget.playerNames,
            scores: _scores,
            winners: winners,
            scoreKey: (i) => Key('reverseFinal$i'),
          ),
        ),
        GradientButton(
          label: s['spy_play_again'],
          icon: Icons.replay_rounded,
          height: 60,
          onPressed: _playAgain,
        ),
        const SizedBox(height: 12),
        GlassButton(
          label: s['spy_finish'],
          icon: Icons.check_rounded,
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

/// A big round play / stop button with its label underneath.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.playLabel,
    required this.stopLabel,
    required this.onTap,
  });

  final bool playing;
  final String playLabel;
  final String stopLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('reversePlayButton'),
          onTap: onTap,
          child: Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: primaryGradient,
            ),
            child: Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          playing ? stopLabel : playLabel,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
