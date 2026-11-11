import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/category_chips.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.mode});

  final GameMode mode;

  static const minPlayers = 2;
  static const maxPlayers = 12;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _defaultPlayers = 4;
  static const _maxNameLength = 14;

  /// One controller per player; its length is the player count.
  final _names = <TextEditingController>[
    for (var i = 0; i < _defaultPlayers; i++) TextEditingController(),
  ];
  Category? _category;

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
      SetupScreen.minPlayers,
      SetupScreen.maxPlayers,
    );
    while (_names.length < target) {
      _names.add(TextEditingController());
    }
    while (_names.length > target) {
      _names.removeLast().dispose();
    }
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
        builder: (_) => GameScreen(
          mode: widget.mode,
          playerNames: names,
          category: _category,
        ),
      ),
    );
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
        child: SafeArea(
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
                          0,
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
                                        onPressed:
                                            _players > SetupScreen.minPlayers
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
                                  Divider(
                                    height: 32,
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.layers_outlined),
                                      const SizedBox(width: 12),
                                      Text(
                                        s['category'],
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  CategoryChips(
                                    selected: _category,
                                    onSelected: (c) =>
                                        setState(() => _category = c),
                                  ),
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

/// Mode icon inside an organic glass "blob" with a soft purple glow.
class _ModeBlob extends StatelessWidget {
  const _ModeBlob({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 154,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.elliptical(92, 80),
          topRight: Radius.elliptical(64, 92),
          bottomRight: Radius.elliptical(88, 68),
          bottomLeft: Radius.elliptical(68, 88),
        ),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFB07CFF).withValues(alpha: 0.7),
            const Color(0xFF5B3A98).withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A5CFF).withValues(alpha: 0.45),
            blurRadius: 32,
          ),
        ],
      ),
      // The icon is filled with the mode's own warm-to-saturated gradient.
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
