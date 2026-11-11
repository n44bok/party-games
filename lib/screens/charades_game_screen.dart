import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../ads/ad_service.dart';
import '../charades/charades_deck.dart';
import '../data/content_repository.dart';
import '../data/content_scope.dart';
import '../data/settings.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../sound/sound_service.dart';
import '../spy/spy_round.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';
import '../widgets/load_error.dart';
import '../widgets/round_parts.dart';

enum _Phase { loading, ready, acting, turnEnd, result }

/// The whole Charades game on one screen.
///
/// Players take turns: the phone is passed to the actor, who sees a word and
/// acts it out while the others guess against a countdown. Each guessed word
/// scores a point for the actor. After the chosen number of rounds the best
/// score wins.
class CharadesGameScreen extends StatefulWidget {
  const CharadesGameScreen({
    super.key,
    required this.playerNames,
    required this.categories,
    required this.turnSeconds,
    required this.rounds,
    this.repository,
    this.random,
  });

  /// Display names in turn order.
  final List<String> playerNames;

  /// The themes the words are drawn from.
  final Set<SpyCategory> categories;

  /// How long each turn lasts.
  final int turnSeconds;

  /// How many times each player acts.
  final int rounds;
  final ContentRepository? repository;

  /// Injectable for tests.
  final Random? random;

  @override
  State<CharadesGameScreen> createState() => _CharadesGameScreenState();
}

class _CharadesGameScreenState extends State<CharadesGameScreen> {
  _Phase _phase = _Phase.loading;
  CharadesDeck? _deck;
  Object? _error;
  bool _loadStarted = false;

  late List<int> _scores = List.filled(_players, 0);
  int _turn = 0; // 0 .. players * rounds - 1
  String _word = '';
  int _guessedThisTurn = 0;

  Timer? _ticker;
  int _remaining = 0;

  int get _players => widget.playerNames.length;
  int get _turns => _players * widget.rounds;
  int get _actor => _turn % _players;
  int get _round => _turn ~/ _players + 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _load();
      // The game's only ad: once, as it starts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AdScope.read(context).showStartInterstitial();
      });
    }
  }

  Future<void> _load() async {
    final s = Strings.of(context);
    final repo = widget.repository ?? ContentScope.of(context);
    try {
      final byCategory = await repo.loadSpyWords(s.code);
      final words = spyWordPool(
        categories: widget.categories,
        byCategory: byCategory,
      );
      if (words.isEmpty) throw StateError('No words for ${widget.categories}');
      if (!mounted) return;
      _deck = CharadesDeck(words, random: widget.random);
      setState(() => _phase = _Phase.ready);
    } catch (e, st) {
      debugPrint('Failed to load the Charades words (${s.code}): $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }

  void _haptic({bool strong = false}) {
    if (!SettingsScope.read(context).haptics) return;
    strong ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
  }

  void _startTurn() {
    _haptic();
    setState(() {
      _word = _deck!.next();
      _guessedThisTurn = 0;
      _remaining = widget.turnSeconds;
      _phase = _Phase.acting;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) return;
      setState(() => _remaining--);
      if (_remaining == 0) _endTurn();
    });
  }

  void _guessed() {
    _haptic();
    setState(() {
      _scores[_actor]++;
      _guessedThisTurn++;
      _word = _deck!.next();
    });
  }

  void _skip() {
    _haptic();
    setState(() => _word = _deck!.next());
  }

  void _endTurn() {
    _ticker?.cancel();
    _haptic(strong: true);
    final SoundService sounds = SoundScope.read(context);
    sounds.playTimeUp();
    setState(() => _phase = _Phase.turnEnd);
  }

  void _nextTurn() {
    if (_turn + 1 >= _turns) {
      setState(() => _phase = _Phase.result);
    } else {
      setState(() {
        _turn++;
        _phase = _Phase.ready;
      });
    }
  }

  void _playAgain() {
    _ticker?.cancel();
    setState(() {
      _scores = List.filled(_players, 0);
      _turn = 0;
      _phase = _Phase.ready;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          s.modeName(GameMode.charades),
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
            child: _error != null
                ? LoadError(
                    message: s['load_error'],
                    details: kDebugMode ? '$_error' : null,
                    retryLabel: s['retry'],
                    onRetry: _retry,
                  )
                : switch (_phase) {
                    _Phase.loading => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    _Phase.ready => _buildReady(s),
                    _Phase.acting => _buildActing(s),
                    _Phase.turnEnd => _buildTurnEnd(s),
                    _Phase.result => _buildResult(s),
                  },
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- ready

  Widget _buildReady(Strings s) {
    return Column(
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            s.format('charades_round', {'n': _round, 'total': widget.rounds}),
            key: const Key('charadesRound'),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Expanded(
          child: Center(
            child: PassCard(
              key: ValueKey('ready$_turn'),
              name: widget.playerNames[_actor],
              label: s['spy_pass_to'],
              nameKey: const Key('charadesActor'),
            ),
          ),
        ),
        GradientButton(
          label: s['charades_ready'],
          icon: Icons.play_arrow_rounded,
          height: 60,
          onPressed: _startTurn,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- acting

  Widget _buildActing(Strings s) {
    final low = _remaining <= 10;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _remaining / widget.turnSeconds,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                    low ? const Color(0xFFFF6A6A) : const Color(0xFFFFC043),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              TimerDial.format(_remaining),
              key: const Key('charadesTimer'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: low ? const Color(0xFFFF9E9E) : Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: GlassCard(
              radius: 32,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.theater_comedy_rounded,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _word,
                      key: const Key('charadesWord'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s['charades_hint'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          s.format('charades_score_short', {'n': _scores[_actor]}),
          key: const Key('charadesScore'),
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 12),
        GradientButton(
          label: s['charades_guessed'],
          icon: Icons.check_rounded,
          height: 60,
          onPressed: _guessed,
        ),
        const SizedBox(height: 12),
        GlassButton(
          label: s['charades_skip'],
          icon: Icons.skip_next_rounded,
          onPressed: _skip,
        ),
      ],
    );
  }

  // --------------------------------------------------------------- turn end

  Widget _buildTurnEnd(Strings s) {
    final last = _turn + 1 >= _turns;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: GlassCard(
              radius: 32,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 56,
                      color: Color(0xFFFFC043),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s['charades_times_up'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s.format('charades_turn_result', {'n': _guessedThisTurn}),
                      key: const Key('charadesTurnResult'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        GradientButton(
          label: last ? s['charades_see_results'] : s['charades_next_player'],
          height: 60,
          onPressed: _nextTurn,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- result

  Widget _buildResult(Strings s) {
    final winners = charadesWinners(_scores);
    final order = [for (var i = 0; i < _players; i++) i]
      ..sort((a, b) {
        final byScore = _scores[b].compareTo(_scores[a]);
        return byScore != 0 ? byScore : a.compareTo(b);
      });
    return Column(
      children: [
        GradientText(
          winners.length == 1
              ? s.format('charades_winner', {
                  'name': widget.playerNames[winners.single],
                })
              : s['charades_tie'],
          key: const Key('charadesWinner'),
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          s['charades_scores'],
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final i in order)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          if (winners.contains(i))
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFFFC043),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              widget.playerNames[i],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${_scores[i]}',
                            key: Key('charadesFinal$i'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
