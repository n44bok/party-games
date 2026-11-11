import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode, this.repository});

  final GameMode mode;
  final ContentRepository? repository;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Prompt>? _deck;
  int _index = 0;
  int _roundsPlayed = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deck == null) _load();
  }

  Future<void> _load() async {
    final s = Strings.of(context);
    final repo = widget.repository ?? ContentRepository();
    final deck = await repo.load(widget.mode, s.code, (f) => s[f]);
    deck.shuffle();
    if (mounted) setState(() => _deck = deck);
  }

  void _next() {
    setState(() {
      _roundsPlayed++;
      _index = (_index + 1) % _deck!.length;
      if (_index == 0) _deck!.shuffle();
    });
    // TODO(ads): show interstitial every N rounds, between rounds only.
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final mode = widget.mode;
    return Scaffold(
      backgroundColor: mode.color,
      appBar: AppBar(
        title: Text(s.modeName(mode)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _deck == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _deck!.isEmpty
                ? Center(
                    child: Text(s['empty'],
                        style: const TextStyle(color: Colors.white)))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _PromptCard(
                              key: ValueKey(_roundsPlayed),
                              prompt: _deck![_index],
                              orLabel: s['or'],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: mode.color,
                            ),
                            onPressed: _next,
                            child: Text(s['next'],
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({super.key, required this.prompt, required this.orLabel});

  final Prompt prompt;
  final String orLabel;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 26, fontWeight: FontWeight.w700);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: prompt.optionB == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (prompt.label != null) ...[
                      Chip(label: Text(prompt.label!)),
                      const SizedBox(height: 16),
                    ],
                    Text(prompt.text,
                        textAlign: TextAlign.center, style: style),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(prompt.text, textAlign: TextAlign.center, style: style),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(orLabel,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Text(prompt.optionB!,
                        textAlign: TextAlign.center, style: style),
                  ],
                ),
        ),
      ),
    );
  }
}
