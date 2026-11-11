import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/category_chips.dart';
import '../widgets/glass.dart';
import '../widgets/glass_blob.dart';
import '../widgets/glass_pill.dart';
import '../widgets/gradient_background.dart';
import '../spy/spy_round.dart';
import 'game_screen.dart';
import 'spy_game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.mode});

  final GameMode mode;

  static const maxPlayers = 12;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _maxNameLength = 14;
  static const _timerMinutes = [5, 8, 10, 15];

  /// One controller per player; its length is the player count.
  late final _names = <TextEditingController>[
    for (var i = 0; i < widget.mode.defaultPlayers; i++)
      TextEditingController(),
  ];
  Category? _category;

  // Spy options.
  SpyCategory _spyCategory = SpyCategory.places;
  int _spies = 1;
  int _minutes = 8;

  @override
  void initState() {
    super.initState();
    if (widget.mode == GameMode.spy) {
      // Spy shows its one ad when the game starts, so have it loaded by then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AdScope.read(context).prepareInterstitial();
      });
    }
  }

  int get _players => _names.length;

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _changePlayers(int delta) => setState(() {
    final target = (_players + delta).clamp(
      widget.mode.minPlayers,
      SetupScreen.maxPlayers,
    );
    while (_names.length < target) {
      _names.add(TextEditingController());
    }
    while (_names.length > target) {
      _names.removeLast().dispose();
    }
    // Fewer players may no longer allow as many spies.
    _spies = _spies.clamp(1, SpyRound.maxSpiesFor(_players));
  });

  void _start() {
    final s = Strings.of(context);
    FocusScope.of(context).unfocus();
    // An empty field falls back to "Player N".
    final names = [
      for (var i = 0; i < _players; i++)
        _names[i].text.trim().isEmpty
            ? s.defaultPlayerName(i + 1)
            : _names[i].text.trim(),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.mode == GameMode.spy
            ? SpyGameScreen(
                playerNames: names,
                spies: _spies,
                duration: Duration(minutes: _minutes),
                category: _spyCategory,
              )
            : GameScreen(
                mode: widget.mode,
                playerNames: names,
                category: _category,
              ),
      ),
    );
  }

  /// The options below the player list: content categories for the card
  /// games, spies and timer for Spy.
  List<Widget> _modeOptions(Strings s, ThemeData theme) {
    Widget header(IconData icon, String label) => Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.titleMedium),
      ],
    );
    final divider = Divider(
      height: 32,
      color: Colors.white.withValues(alpha: 0.14),
    );

    if (widget.mode != GameMode.spy) {
      return [
        divider,
        header(Icons.layers_outlined, s['category']),
        const SizedBox(height: 14),
        CategoryChips(
          selected: _category,
          onSelected: (c) => setState(() => _category = c),
        ),
      ];
    }

    final maxSpies = SpyRound.maxSpiesFor(_players);
    return [
      divider,
      header(Icons.category_outlined, s['spy_words']),
      const SizedBox(height: 14),
      OptionPills<SpyCategory>(
        key: const Key('spyCategoryPills'),
        options: [for (final c in SpyCategory.values) (c, s[c.labelKey])],
        selected: _spyCategory,
        onSelected: (c) => setState(() => _spyCategory = c),
      ),
      const SizedBox(height: 24),
      header(Icons.person_search_outlined, s['spies']),
      const SizedBox(height: 14),
      OptionPills<int>(
        key: const Key('spyCountPills'),
        options: const [(1, '1'), (2, '2')],
        selected: _spies,
        isEnabled: (n) => n <= maxSpies,
        onSelected: (n) => setState(() => _spies = n),
      ),
      const SizedBox(height: 24),
      header(Icons.timer_outlined, s['timer']),
      const SizedBox(height: 14),
      OptionPills<int>(
        key: const Key('timerPills'),
        options: [
          for (final m in _timerMinutes) (m, s.format('minutes', {'n': m})),
        ],
        selected: _minutes,
        onSelected: (m) => setState(() => _minutes = m),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final mode = widget.mode;
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
        ),
      ),
      body: GradientBackground(
        // The illustration is part of the scrolling page, anchored under the
        // button; the name fields can make the page taller than the screen.
        // No SafeArea at the top: the scroll view must reach the screen edge,
        // otherwise it clips the blob's glow along the status-bar line. The
        // top inset (which already includes the app bar, because the body extends
        // behind it) is added as padding inside instead.
        child: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final backdropHeight = MediaQuery.sizeOf(context).height * 0.36;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: backdropHeight,
                        child: const _PartyBackdrop(),
                      ),
                      Padding(
                        // Leave room so the button sits above the picture.
                        padding: EdgeInsets.fromLTRB(
                          20,
                          MediaQuery.paddingOf(context).top,
                          20,
                          backdropHeight * 0.6,
                        ),
                        child: Column(
                          children: [
                            _ModeBlob(mode: mode),
                            const SizedBox(height: 14),
                            _ModeTitle(title: s.modeName(mode)),
                            const SizedBox(height: 6),
                            Text(
                              s['${mode.id}_desc'],
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 24),
                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.group_outlined),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          s['players'],
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                      GlassIconButton(
                                        icon: Icons.remove,
                                        tooltip: '−',
                                        onPressed: _players > mode.minPlayers
                                            ? () => _changePlayers(-1)
                                            : null,
                                      ),
                                      SizedBox(
                                        width: 48,
                                        child: Text(
                                          '$_players',
                                          key: const Key('playersCount'),
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      GlassIconButton(
                                        icon: Icons.add,
                                        tooltip: '+',
                                        onPressed:
                                            _players < SetupScreen.maxPlayers
                                            ? () => _changePlayers(1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  for (var i = 0; i < _players; i++) ...[
                                    if (i > 0) const SizedBox(height: 10),
                                    _NameField(
                                      controller: _names[i],
                                      hint: s.defaultPlayerName(i + 1),
                                      maxLength: _maxNameLength,
                                      isLast: i == _players - 1,
                                    ),
                                  ],
                                  ..._modeOptions(s, theme),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            GradientButton(
                              label: s['start'],
                              icon: Icons.play_arrow_rounded,
                              onPressed: _start,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Single-line glass text field for one player's name.
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.isLast,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: alpha)),
    );
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: 1,
      textCapitalization: TextCapitalization.words,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: border(0.16),
        focusedBorder: border(0.6),
        border: border(0.16),
      ),
    );
  }
}

/// Mode icon on a glass blob, filled with the mode's own gradient.
class _ModeBlob extends StatelessWidget {
  const _ModeBlob({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return GlassBlob(
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          colors: mode == GameMode.truthOrDare
              ? const [Color(0xFFFFB074), Color(0xFFFF4F92)] // warm flame
              : [mode.tint, mode.glow],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
        child: Icon(mode.icon, size: 96, color: Colors.white),
      ),
    );
  }
}

/// Title where the connecting word ("or" / "чи") gets a lavender accent.
class _ModeTitle extends StatelessWidget {
  const _ModeTitle({required this.title});

  final String title;

  static final _connector = RegExp(r'( or | чи )');

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 38,
      height: 1.1,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );
    final match = _connector.firstMatch(title);
    if (match == null) {
      return Text(title, textAlign: TextAlign.center, style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: title.substring(0, match.start)),
          TextSpan(
            text: match.group(0),
            style: const TextStyle(color: Color(0xFFC9A8FF)),
          ),
          TextSpan(text: title.substring(match.end)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Illustration of friends toasting, anchored to the bottom and faded into
/// the background at the top.
class _PartyBackdrop extends StatelessWidget {
  const _PartyBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.transparent, Colors.black],
          stops: [0.0, 0.45],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
        child: Image.asset(
          'assets/images/party_toast.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          // Decorative only; never break the screen over a missing image.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
