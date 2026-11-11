import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../ads/ad_service.dart';
import '../data/content_repository.dart';
import '../data/content_scope.dart';
import '../data/settings.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../spy/spy_round.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';
import '../widgets/load_error.dart';

enum _Phase { loading, reveal, discussion, result }

/// The whole Spy game on one screen.
///
/// 1. **Reveal:** the phone is passed around; each player taps to see their
///    secret role (the word, or "you are the spy") and hides it again.
/// 2. **Discussion:** a countdown while everyone asks questions.
/// 3. **Result:** who the spy was and what the word was; play again.
class SpyGameScreen extends StatefulWidget {
  const SpyGameScreen({
    super.key,
    required this.playerNames,
    required this.spies,
    required this.duration,
    this.category = SpyCategory.places,
    this.repository,
    this.random,
  });

  /// Display names in turn order; their count is the number of players.
  final List<String> playerNames;
  final int spies;

  /// How long the discussion lasts.
  final Duration duration;

  /// The theme of the secret words.
  final SpyCategory category;
  final ContentRepository? repository;

  /// Injectable for tests.
  final Random? random;

  @override
  State<SpyGameScreen> createState() => _SpyGameScreenState();
}

class _SpyGameScreenState extends State<SpyGameScreen> {
  _Phase _phase = _Phase.loading;
  List<String>? _words;
  Object? _error;
  bool _loadStarted = false;

  SpyRound? _round;
  int _turn = 0; // whose role is being shown
  bool _revealed = false;

  Timer? _ticker;
  int _remaining = 0;
  bool _paused = false;

  /// Words the user has crossed off in the list; reset each round.
  final _crossedOut = <String>{};

  int get _players => widget.playerNames.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _load();
      // The game's only ad: once, as it starts. Rounds after "Play again"
      // belong to the same game and get none; leaving to the setup screen
      // and starting again makes a new game, and so a new ad.
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
      final words = byCategory[widget.category.id];
      if (words == null || words.isEmpty) {
        throw StateError('No Spy words for ${widget.category.id}');
      }
      if (!mounted) return;
      _words = words;
      _newRound();
    } catch (e, st) {
      debugPrint('Failed to load the Spy words (${s.code}): $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }

  void _newRound() {
    _ticker?.cancel();
    setState(() {
      _round = SpyRound.start(
        players: _players,
        spies: widget.spies,
        words: _words!,
        random: widget.random,
      );
      _turn = 0;
      _revealed = false;
      _crossedOut.clear();
      _phase = _Phase.reveal;
    });
  }

  void _haptic({bool strong = false}) {
    if (!SettingsScope.of(context).haptics) return;
    strong ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
  }

  void _showRole() {
    _haptic();
    setState(() => _revealed = true);
  }

  void _hideRole() {
    setState(() {
      _revealed = false;
      _turn++;
    });
    if (_turn >= _players) _startDiscussion();
  }

  void _startDiscussion() {
    setState(() {
      _phase = _Phase.discussion;
      _remaining = widget.duration.inSeconds;
      _paused = false;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || _remaining <= 0) return;
      setState(() => _remaining--);
      if (_remaining == 0) {
        _ticker?.cancel();
        _haptic(strong: true);
      }
    });
  }

  void _reveal() {
    _ticker?.cancel();
    setState(() => _phase = _Phase.result);
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
          s.modeName(GameMode.spy),
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
                    _Phase.reveal => _buildReveal(s),
                    _Phase.discussion => _buildDiscussion(s),
                    _Phase.result => _buildResult(s),
                  },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- reveal

  Widget _buildReveal(Strings s) {
    final round = _round!;
    final isLast = _turn == _players - 1;
    final name = widget.playerNames[_turn];
    return Column(
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '${_turn + 1} / $_players',
            key: const Key('spyProgress'),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Expanded(
          child: Center(
            child: _revealed
                ? _RoleCard(
                    key: ValueKey('role$_turn'),
                    isSpy: round.isSpy(_turn),
                    location: round.word,
                    strings: s,
                  )
                : _PassCard(
                    key: ValueKey('pass$_turn'),
                    name: name,
                    strings: s,
                  ),
          ),
        ),
        GradientButton(
          label: _revealed
              ? (isLast ? s['spy_hide_start'] : s['spy_hide_next'])
              : s['spy_show_role'],
          height: 60,
          onPressed: _revealed ? _hideRole : _showRole,
        ),
      ],
    );
  }

  // ------------------------------------------------------------ discussion

  Widget _buildDiscussion(Strings s) {
    final round = _round!;
    final timeUp = _remaining == 0;
    return Column(
      children: [
        GlassCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
            s.format('spy_asks_first', {
              'name': widget.playerNames[round.firstAsker],
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Expanded(
          child: Center(
            child: _TimerDial(
              seconds: _remaining,
              total: widget.duration.inSeconds,
              caption: timeUp ? s['spy_times_up'] : s['spy_time_left'],
              highlight: timeUp,
            ),
          ),
        ),
        Row(
          children: [
            if (!timeUp) ...[
              Expanded(
                child: GlassButton(
                  label: _paused ? s['spy_resume'] : s['spy_pause'],
                  icon: _paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onPressed: () => setState(() => _paused = !_paused),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: GlassButton(
                label: s['spy_locations'],
                icon: Icons.place_outlined,
                onPressed: () => _showPlaces(s),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GradientButton(label: s['spy_reveal'], height: 60, onPressed: _reveal),
      ],
    );
  }

  void _showPlaces(Strings s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlacesSheet(
        title: s['spy_locations'],
        places: _words!,
        crossedOut: _crossedOut,
      ),
    );
  }

  // ---------------------------------------------------------------- result

  Widget _buildResult(Strings s) {
    final round = _round!;
    final spyNames = [
      for (final i in (round.spyIndexes.toList()..sort()))
        widget.playerNames[i],
    ];
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spyNames.length == 1 ? s['spy_was_one'] : s['spy_was_many'],
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final name in spyNames)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GradientText(
                        name,
                        key: const Key('spyName'),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  GlassCard(
                    radius: 28,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 22,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s['spy_place_was'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          round.word,
                          key: const Key('spyResultWord'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GradientButton(
          label: s['spy_play_again'],
          icon: Icons.replay_rounded,
          height: 60,
          onPressed: _newRound,
        ),
        const SizedBox(height: 12),
        GlassButton(
          label: s['spy_finish'],
          icon: Icons.check_rounded,
          // Done with the game: all the way back to the home screen (not just
          // to the setup screen).
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

/// "Pass the phone to NAME": shown before a player looks at their role.
class _PassCard extends StatelessWidget {
  const _PassCard({super.key, required this.name, required this.strings});

  final String name;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 32,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phone_iphone_rounded,
              size: 52,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              strings['spy_pass_to'],
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            _GradientText(
              name,
              key: const Key('spyPassName'),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// A player's secret: the word, or the news that they are the spy.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.isSpy,
    required this.location,
    required this.strings,
  });

  final bool isSpy;
  final String location;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    return GlassCard(
      radius: 32,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      gradient: LinearGradient(
        colors: isSpy
            ? [
                const Color(0xFFE0457A).withValues(alpha: 0.45),
                const Color(0xFF3A1230).withValues(alpha: 0.9),
              ]
            : [
                const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                const Color(0xFF1E1236).withValues(alpha: 0.9),
              ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: SizedBox(
        width: double.infinity,
        child: isSpy
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_search_rounded,
                    size: 64,
                    color: Color(0xFFFF9EC4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s['spy_you_are_spy'],
                    key: const Key('spyRole'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s['spy_spy_hint'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 56,
                    color: Color(0xFFC9A8FF),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s['spy_location_label'],
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    location,
                    key: const Key('spyWord'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The countdown: a ring that drains, with the time inside.
class _TimerDial extends StatelessWidget {
  const _TimerDial({
    required this.seconds,
    required this.total,
    required this.caption,
    required this.highlight,
  });

  final int seconds;
  final int total;
  final String caption;

  /// Time is up.
  final bool highlight;

  static String format(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: total == 0 ? 0 : seconds / total,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(
                highlight ? const Color(0xFFFF6A6A) : const Color(0xFFF06FB5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  format(seconds),
                  key: const Key('spyTimer'),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: highlight
                        ? const Color(0xFFFF9E9E)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with every possible word; tapping crosses one off.
class _PlacesSheet extends StatefulWidget {
  const _PlacesSheet({
    required this.title,
    required this.places,
    required this.crossedOut,
  });

  final String title;
  final List<String> places;

  /// Owned by the game screen so the marks survive closing the sheet.
  final Set<String> crossedOut;

  @override
  State<_PlacesSheet> createState() => _PlacesSheetState();
}

class _PlacesSheetState extends State<_PlacesSheet> {
  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF1B1230),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final place in widget.places)
                      _PlaceChip(
                        place: place,
                        crossedOut: widget.crossedOut.contains(place),
                        onTap: () => setState(() {
                          if (!widget.crossedOut.add(place)) {
                            widget.crossedOut.remove(place);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({
    required this.place,
    required this.crossedOut,
    required this.onTap,
  });

  final String place;
  final bool crossedOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: crossedOut ? 0.03 : 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Text(
          place,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: crossedOut ? 0.35 : 1),
            decoration: crossedOut ? TextDecoration.lineThrough : null,
            decorationColor: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Text filled with the brand gradient.
class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => brandGradient.createShader(rect),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
