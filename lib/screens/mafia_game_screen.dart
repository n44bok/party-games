import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../ads/ad_service.dart';
import '../data/settings.dart';
import '../data/strings.dart';
import '../mafia/mafia_round.dart';
import '../models/game_mode.dart';
import '../sound/sound_service.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';
import '../widgets/round_parts.dart';

enum _Phase { reveal, host, day, result }

/// The whole Mafia game on one screen.
///
/// 1. **Reveal:** the phone is passed around; each player taps to see their
///    secret role (the mafia also see who else is mafia) and hides it again.
/// 2. **Host** (optional): a separate host sees everyone's roles.
/// 3. **Day:** a countdown while everyone discusses and votes. The nights are
///    run by the players or the host; the app does not narrate them.
/// 4. **Result:** every player's role; play again with fresh roles.
class MafiaGameScreen extends StatefulWidget {
  const MafiaGameScreen({
    super.key,
    required this.playerNames,
    required this.mafia,
    required this.duration,
    this.doctor = true,
    this.detective = true,
    this.withHost = false,
    this.random,
  });

  /// Display names in turn order; their count is the number of players.
  final List<String> playerNames;
  final int mafia;
  final bool doctor;
  final bool detective;

  /// A separate host sees all the roles after the players have seen theirs.
  final bool withHost;

  /// How long the day discussion lasts.
  final Duration duration;

  /// Injectable for tests.
  final Random? random;

  @override
  State<MafiaGameScreen> createState() => _MafiaGameScreenState();
}

class _MafiaGameScreenState extends State<MafiaGameScreen> {
  _Phase _phase = _Phase.reveal;
  late MafiaRound _round = _deal();
  int _turn = 0; // whose role is being shown
  bool _revealed = false;
  bool _hostSees = false;
  bool _adRequested = false;

  Timer? _ticker;
  int _remaining = 0;
  bool _paused = false;

  int get _players => widget.playerNames.length;

  MafiaRound _deal() => MafiaRound.start(
    players: widget.playerNames.length,
    mafia: widget.mafia,
    doctor: widget.doctor,
    detective: widget.detective,
    random: widget.random,
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
      _round = _deal();
      _turn = 0;
      _revealed = false;
      _hostSees = false;
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
    if (_turn >= _players) {
      widget.withHost ? setState(() => _phase = _Phase.host) : _startDay();
    }
  }

  void _startDay() {
    setState(() {
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

  void _showResult() {
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
              _Phase.day => _buildDay(s),
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
                              if (i != _turn) widget.playerNames[i],
                          ]
                        : const [],
                    strings: s,
                  )
                : PassCard(
                    key: ValueKey('pass$_turn'),
                    name: widget.playerNames[_turn],
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
                  round: _round,
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

  // ------------------------------------------------------------------- day

  Widget _buildDay(Strings s) {
    final timeUp = _remaining == 0;
    return Column(
      children: [
        GlassCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
            s.format('mafia_speaks_first', {
              'name': widget.playerNames[_round.firstSpeaker],
            }),
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
                  _RolesInPlay(round: _round, strings: s),
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
          label: s['mafia_reveal'],
          height: 60,
          onPressed: _showResult,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- result

  Widget _buildResult(Strings s) {
    return Column(
      children: [
        Expanded(
          child: _RoleList(
            title: s['mafia_roles_were'],
            names: widget.playerNames,
            round: _round,
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
  const _RolesInPlay({required this.round, required this.strings});

  final MafiaRound round;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
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

/// Every player with their role, mafia first.
class _RoleList extends StatelessWidget {
  const _RoleList({
    required this.title,
    required this.names,
    required this.round,
    required this.strings,
    this.hint,
  });

  final String title;
  final List<String> names;
  final MafiaRound round;
  final Strings strings;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final order = [for (var i = 0; i < names.length; i++) i]
      ..sort((a, b) {
        final byRole = round.roleOf(a).index.compareTo(round.roleOf(b).index);
        return byRole != 0 ? byRole : a.compareTo(b);
      });
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                              names[i],
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
