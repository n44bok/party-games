import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/category_chips.dart';
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
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: mode.gradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(mode.icon, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  s.modeName(mode),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                        const Divider(height: 32),
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
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      s['start'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
