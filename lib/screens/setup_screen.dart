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
  int _players = 4;
  Category? _category;

  void _changePlayers(int delta) => setState(
    () => _players = (_players + delta).clamp(
      SetupScreen.minPlayers,
      SetupScreen.maxPlayers,
    ),
  );

  void _start() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: widget.mode,
          players: _players,
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
      appBar: AppBar(),
      body: GradientBackground(
        child: Stack(
          children: [
            const _PartyBackdrop(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        gradient: mode.gradient,
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: mode.color.withValues(alpha: 0.5),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                      child: Icon(mode.icon, size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.modeName(mode),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s['${mode.id}_desc'],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
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
                              IconButton.filledTonal(
                                tooltip: '−',
                                onPressed: _players > SetupScreen.minPlayers
                                    ? () => _changePlayers(-1)
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '$_players',
                                  key: const Key('playersCount'),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: '+',
                                onPressed: _players < SetupScreen.maxPlayers
                                    ? () => _changePlayers(1)
                                    : null,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          Divider(
                            height: 32,
                            color: Colors.white.withValues(alpha: 0.16),
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
                          const SizedBox(height: 12),
                          CategoryChips(
                            selected: _category,
                            onSelected: (c) => setState(() => _category = c),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: s['start'],
                      icon: Icons.play_arrow_rounded,
                      onPressed: _start,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Illustration of friends toasting, anchored to the bottom and faded into
/// the background at the top.
class _PartyBackdrop extends StatelessWidget {
  const _PartyBackdrop();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.36;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: IgnorePointer(
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
      ),
    );
  }
}
