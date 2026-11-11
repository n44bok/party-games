import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../ads/ad_service.dart';
import '../data/settings.dart';
import '../data/strings.dart';
import '../mafia/mafia_game.dart';
import '../mafia/mafia_round.dart';
import '../models/game_mode.dart';
import '../sound/sound_service.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';
import '../widgets/round_parts.dart';

enum _Phase {
  reveal,
  host,
  nightIntro,
  nightMafia,
  nightDoctor,
  nightDetective,
  morning,
  day,
  vote,
  voted,
  result,
}

/// The whole Mafia game on one screen.
///
/// 1. **Reveal:** the phone is passed around; each player taps to see their
///    secret role (the mafia also see who else is mafia) and hides it again.
/// 2. **Nights** (when the app runs them): everyone closes their eyes and the
///    app calls the mafia, the doctor and the detective in turn.
///    Otherwise a host sees all the roles and runs the nights.
/// 3. **Day:** a countdown while everyone discusses, then a vote.
/// 4. **Result:** who won and every player's role; play again.
class MafiaGameScreen extends StatefulWidget {
  const MafiaGameScreen({
    super.key,
    required this.playerNames,
    required this.mafia,
    required this.duration,
    this.doctor = true,
    this.detective = true,
    this.appRunsNights = true,
    this.random,
  });

  /// Display names in turn order; their count is the number of players.
  final List<String> playerNames;
  final int mafia;
  final bool doctor;
  final bool detective;

  /// The app narrates the nights and keeps track of who is out. When it does
  /// not, a separate host sees all the roles and runs the game by hand.
  final bool appRunsNights;

  /// How long the day discussion lasts.
  final Duration duration;

  /// Injectable for tests.
  final Random? random;

  @override
  State<MafiaGameScreen> createState() => _MafiaGameScreenState();
}

class _MafiaGameScreenState extends State<MafiaGameScreen> {
  _Phase _phase = _Phase.reveal;
  late MafiaGame _game = _newGame();
  int _turn = 0; // whose role is being shown
  bool _revealed = false;
  bool _hostSees = false;
  bool _adRequested = false;

  // The current night.
  int _night = 1;
  int? _selected; // the pick on the current screen
  int? _victim;
  int? _saved;
  int? _checked;
  bool _checkShown = false;
  int? _lastOut; // eliminated at night, or voted out
  int _speaker = 0;

  Timer? _ticker;
  int _remaining = 0;
  bool _paused = false;

  MafiaRound get _round => _game.round;
  int get _players => widget.playerNames.length;
  String _name(int i) => widget.playerNames[i];

  MafiaGame _newGame() => MafiaGame(
    MafiaRound.start(
      players: widget.playerNames.length,
      mafia: widget.mafia,
      doctor: widget.doctor,
      detective: widget.detective,
      random: widget.random,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_adRequested) {
      _adRequested = true;
      // The game's only ad: once, as it starts (see the Spy screen).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AdScope.read(context).showStartInterstitial();
      });
    }
  }

  void _newRound() {
    _ticker?.cancel();
    setState(() {
      _game = _newGame();
      _turn = 0;
      _revealed = false;
      _hostSees = false;
      _night = 1;
      _selected = _victim = _saved = _checked = _lastOut = null;
      _checkShown = false;
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
    if (_turn < _players) return;
    if (widget.appRunsNights) {
      setState(() => _phase = _Phase.nightIntro);
    } else {
      setState(() => _phase = _Phase.host);
    }
  }

  // ---------------------------------------------------------------- nights

  void _goTo(_Phase phase) => setState(() {
    _selected = null;
    _phase = phase;
  });

  void _afterMafia() {
    _victim = _selected;
    if (_round.count(MafiaRole.doctor) > 0) return _goTo(_Phase.nightDoctor);
    _afterDoctor();
  }

  void _afterDoctor() {
    _saved = _phase == _Phase.nightDoctor ? _selected : null;
    if (_round.count(MafiaRole.detective) > 0) {
      _checkShown = false;
      return _goTo(_Phase.nightDetective);
    }
    _morning();
  }

  void _morning() {
    _lastOut = _game.resolveNight(victim: _victim!, saved: _saved);
    _victim = _saved = _checked = null;
    _goTo(_Phase.morning);
  }

  void _afterMorning() {
    _game.winner != null ? _goTo(_Phase.result) : _startDay();
  }

  void _afterVote() {
    _lastOut = _selected;
    if (_selected != null) _game.voteOut(_selected!);
    _goTo(_Phase.voted);
  }

  void _afterVoted() {
    if (_game.winner != null) return _goTo(_Phase.result);
    _night++;
    _goTo(_Phase.nightIntro);
  }

  // ------------------------------------------------------------------- day

  void _startDay() {
    final rng = widget.random ?? Random();
    final alive = _game.alive;
    setState(() {
      _speaker = widget.appRunsNights
          ? alive[rng.nextInt(alive.length)]
          : _round.firstSpeaker;
      _phase = _Phase.day;
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
        final SoundService sounds = SoundScope.read(context);
        sounds.playTimeUp();
      }
    });
  }

  /// End of the day discussion: to the vote, or (with a host) the result.
  void _endDay() {
    _ticker?.cancel();
    _goTo(widget.appRunsNights ? _Phase.vote : _Phase.result);
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
          s.modeName(GameMode.mafia),
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
            child: switch (_phase) {
              _Phase.reveal => _buildReveal(s),
              _Phase.host => _buildHost(s),
              _Phase.nightIntro => _narration(
                s,
                icon: Icons.nightlight_round,
                title: s.format('mafia_night', {'n': _night}),
                body: s['mafia_close_eyes'],
                onNext: () => _goTo(_Phase.nightMafia),
              ),
              _Phase.nightMafia => _pick(
                s,
                icon: Icons.nightlight_round,
                title: s['mafia_wake_mafia'],
                body: s['mafia_pick_victim'],
                choices: _game.aliveNonMafia,
                onConfirm: _afterMafia,
              ),
              _Phase.nightDoctor => _pick(
                s,
                icon: Icons.medical_services_rounded,
                title: s['mafia_wake_doctor'],
                body: s['mafia_pick_save'],
                choices: _game.alive,
                onConfirm: _afterDoctor,
              ),
              _Phase.nightDetective => _buildDetective(s),
              _Phase.morning => _narration(
                s,
                icon: Icons.wb_sunny_rounded,
                title: s['mafia_morning'],
                body: _lastOut == null
                    ? s['mafia_nobody_killed']
                    : s.format('mafia_killed', {'name': _name(_lastOut!)}),
                hint: s['mafia_morning_hint'],
                onNext: _afterMorning,
                bodyKey: const Key('mafiaMorning'),
              ),
              _Phase.day => _buildDay(s),
              _Phase.vote => _pick(
                s,
                icon: Icons.how_to_vote_rounded,
                title: s['mafia_vote_title'],
                choices: _game.alive,
                confirmLabel: s['mafia_vote_out'],
                onConfirm: _afterVote,
                skipLabel: s['mafia_vote_nobody'],
                onSkip: () {
                  _selected = null;
                  _afterVote();
                },
              ),
              _Phase.voted => _narration(
                s,
                icon: Icons.how_to_vote_rounded,
                title: _lastOut == null
                    ? s['mafia_nobody_voted']
                    : s.format('mafia_voted_out', {'name': _name(_lastOut!)}),
                onNext: _afterVoted,
                bodyKey: const Key('mafiaVoted'),
              ),
              _Phase.result => _buildResult(s),
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- reveal

  Widget _buildReveal(Strings s) {
    final isLast = _turn == _players - 1;
    final role = _round.roleOf(_turn);
    return Column(
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '${_turn + 1} / $_players',
            key: const Key('mafiaProgress'),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Expanded(
          child: Center(
            child: _revealed
                ? _RoleCard(
                    key: ValueKey('role$_turn'),
                    role: role,
                    teammates: role.isMafia
                        ? [
                            for (final i in _round.mafiaIndexes)
                              if (i != _turn) _name(i),
                          ]
                        : const [],
                    strings: s,
                  )
                : PassCard(
                    key: ValueKey('pass$_turn'),
                    name: _name(_turn),
                    label: s['spy_pass_to'],
                    nameKey: const Key('mafiaPassName'),
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

  // ------------------------------------------------------------------ host

  Widget _buildHost(Strings s) {
    return Column(
      children: [
        Expanded(
          child: _hostSees
              ? _RoleList(
                  title: s['mafia_host_title'],
                  names: widget.playerNames,
                  game: _game,
                  strings: s,
                  hint: s['mafia_host_hint'],
                )
              : Center(
                  child: PassCard(
                    name: s['mafia_host'],
                    label: s['spy_pass_to'],
                    nameKey: const Key('mafiaHostName'),
                  ),
                ),
        ),
        GradientButton(
          label: _hostSees ? s['spy_hide_start'] : s['spy_show_role'],
          height: 60,
          onPressed: _hostSees
              ? () {
                  setState(() => _hostSees = false);
                  _startDay();
                }
              : () {
                  _haptic();
                  setState(() => _hostSees = true);
                },
        ),
      ],
    );
  }

  // ------------------------------------------------------------- narration

  /// A full-screen message with a continue button.
  Widget _narration(
    Strings s, {
    required IconData icon,
    required String title,
    String? body,
    String? hint,
    required VoidCallback onNext,
    Key? bodyKey,
  }) {
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
                    Icon(icon, size: 60, color: const Color(0xFFC9A8FF)),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      key: body == null && bodyKey != null
                          ? bodyKey
                          : const Key('mafiaTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        body,
                        key: bodyKey,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    if (hint != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        GradientButton(
          label: s['mafia_continue'],
          height: 60,
          onPressed: onNext,
        ),
      ],
    );
  }

  /// A list of players to choose one from, with a confirm button.
  Widget _pick(
    Strings s, {
    required IconData icon,
    required String title,
    String? body,
    required List<int> choices,
    required VoidCallback onConfirm,
    String? confirmLabel,
    String? skipLabel,
    VoidCallback? onSkip,
  }) {
    return Column(
      children: [
        Icon(icon, size: 40, color: const Color(0xFFC9A8FF)),
        const SizedBox(height: 8),
        Text(
          title,
          key: const Key('mafiaTitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final i in choices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PickTile(
                      key: Key('pick$i'),
                      name: _name(i),
                      selected: _selected == i,
                      onTap: () {
                        _haptic();
                        setState(() => _selected = i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (skipLabel != null) ...[
          GlassButton(
            label: skipLabel,
            icon: Icons.block_rounded,
            onPressed: onSkip!,
          ),
          const SizedBox(height: 12),
        ],
        // Nothing to confirm until someone is picked.
        IgnorePointer(
          ignoring: _selected == null,
          child: Opacity(
            opacity: _selected == null ? 0.4 : 1,
            child: GradientButton(
              key: const Key('mafiaConfirm'),
              label: confirmLabel ?? s['mafia_confirm'],
              height: 60,
              onPressed: onConfirm,
            ),
          ),
        ),
      ],
    );
  }

  /// The detective picks someone, then learns whether they are mafia.
  Widget _buildDetective(Strings s) {
    if (!_checkShown) {
      return _pick(
        s,
        icon: Icons.search_rounded,
        title: s['mafia_wake_detective'],
        body: s['mafia_pick_check'],
        choices: _game.alive,
        onConfirm: () => setState(() {
          _checked = _selected;
          _checkShown = true;
        }),
      );
    }
    final mafia = _game.isMafia(_checked!);
    return _narration(
      s,
      icon: Icons.search_rounded,
      title: s.format(mafia ? 'mafia_check_mafia' : 'mafia_check_clean', {
        'name': _name(_checked!),
      }),
      onNext: _morning,
      bodyKey: const Key('mafiaCheck'),
    );
  }

  // ------------------------------------------------------------------- day

  Widget _buildDay(Strings s) {
    final timeUp = _remaining == 0;
    return Column(
      children: [
        GlassCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
            s.format('mafia_speaks_first', {'name': _name(_speaker)}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TimerDial(
                    seconds: _remaining,
                    total: widget.duration.inSeconds,
                    caption: timeUp ? s['mafia_times_up'] : s['spy_time_left'],
                    highlight: timeUp,
                    timerKey: const Key('mafiaTimer'),
                  ),
                  const SizedBox(height: 20),
                  _RolesInPlay(game: _game, strings: s),
                ],
              ),
            ),
          ),
        ),
        if (!timeUp) ...[
          GlassButton(
            label: _paused ? s['spy_resume'] : s['spy_pause'],
            icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onPressed: () => setState(() => _paused = !_paused),
          ),
          const SizedBox(height: 12),
        ],
        GradientButton(
          label: widget.appRunsNights ? s['mafia_to_vote'] : s['mafia_reveal'],
          height: 60,
          onPressed: _endDay,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- result

  Widget _buildResult(Strings s) {
    final winner = _game.winner;
    return Column(
      children: [
        Expanded(
          child: _RoleList(
            title: winner == null
                ? s['mafia_roles_were']
                : winner == MafiaSide.citizens
                ? s['mafia_citizens_win']
                : s['mafia_mafia_wins'],
            titleKey: const Key('mafiaWinner'),
            names: widget.playerNames,
            game: _game,
            strings: s,
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
          // Done with the game: all the way back to the home screen.
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

/// One choosable player in a list.
class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        gradient: selected
            ? LinearGradient(
                colors: [
                  const Color(0xFFB45CF5).withValues(alpha: 0.55),
                  const Color(0xFF2A1750).withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded),
          ],
        ),
      ),
    );
  }
}

const _mafiaPink = Color(0xFFFF9EC4);

IconData _roleIcon(MafiaRole role) => switch (role) {
  MafiaRole.mafia => Icons.nightlight_round,
  MafiaRole.doctor => Icons.medical_services_rounded,
  MafiaRole.detective => Icons.search_rounded,
  MafiaRole.citizen => Icons.person_rounded,
};

Color _roleColor(MafiaRole role) =>
    role.isMafia ? _mafiaPink : const Color(0xFFC9A8FF);

/// A player's secret role, with a hint and (for the mafia) their team.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.role,
    required this.teammates,
    required this.strings,
  });

  final MafiaRole role;

  /// The other mafia members (only for a mafia member).
  final List<String> teammates;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final mafia = role.isMafia;
    return GlassCard(
      radius: 32,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      gradient: LinearGradient(
        colors: mafia
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_roleIcon(role), size: 60, color: _roleColor(role)),
            const SizedBox(height: 12),
            Text(
              s['mafia_you_are'],
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s[role.nameKey],
              key: const Key('mafiaRole'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              s[role.hintKey],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            if (mafia) ...[
              const SizedBox(height: 16),
              Text(
                teammates.isEmpty
                    ? s['mafia_alone']
                    : s.format('mafia_team', {'names': teammates.join(', ')}),
                key: const Key('mafiaTeam'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _mafiaPink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Which roles are in the game and how many of each, shown while the players
/// talk (not who has them).
class _RolesInPlay extends StatelessWidget {
  const _RolesInPlay({required this.game, required this.strings});

  final MafiaGame game;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    return Wrap(
      key: const Key('mafiaRolesInPlay'),
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in MafiaRole.values)
          if (round.count(role) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_roleIcon(role), size: 16, color: _roleColor(role)),
                  const SizedBox(width: 6),
                  Text(
                    '${strings[role.nameKey]} ×${round.count(role)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Every player with their role, mafia first. Players who are out are dimmed
/// and marked.
class _RoleList extends StatelessWidget {
  const _RoleList({
    required this.title,
    required this.names,
    required this.game,
    required this.strings,
    this.hint,
    this.titleKey,
  });

  final String title;
  final Key? titleKey;
  final List<String> names;
  final MafiaGame game;
  final Strings strings;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final round = game.round;
    final order = [for (var i = 0; i < names.length; i++) i]
      ..sort((a, b) {
        final byRole = round.roleOf(a).index.compareTo(round.roleOf(b).index);
        return byRole != 0 ? byRole : a.compareTo(b);
      });
    return Column(
      children: [
        Text(
          title,
          key: titleKey,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final i in order)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Opacity(
                      opacity: game.isAlive(i) ? 1 : 0.5,
                      child: GlassCard(
                        radius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _roleIcon(round.roleOf(i)),
                              color: _roleColor(round.roleOf(i)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                game.isAlive(i)
                                    ? names[i]
                                    : '${names[i]} · ${strings['mafia_out']}',
                                key: Key('mafiaListName$i'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              strings[round.roleOf(i).nameKey],
                              key: Key('mafiaListRole$i'),
                              style: TextStyle(
                                fontSize: 16,
                                color: _roleColor(round.roleOf(i)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
