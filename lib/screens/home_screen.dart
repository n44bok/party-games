import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';
import 'game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(s['title'],
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(s['subtitle'], style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: GameMode.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final mode = GameMode.values[i];
                    return _ModeCard(
                      mode: mode,
                      title: s.modeName(mode),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => GameScreen(mode: mode)),
                      ),
                    );
                  },
                ),
              ),
              // TODO(ads): banner placeholder goes here.
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard(
      {required this.mode, required this.title, required this.onTap});

  final GameMode mode;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: mode.color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(mode.icon, size: 48, color: Colors.white),
              const SizedBox(width: 20),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
