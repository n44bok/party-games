import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/gradient_background.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    this.players = 4,
    this.category,
    this.repository,
  });

  final GameMode mode;
  final int players;

  /// `null` means all categories.
  final Category? category;
  final ContentRepository? repository;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Prompt>? _deck;
  int _index = 0;
  int _turn = 0; // number of prompts shown so far; drives current player
  int _cardKey = 0; // bumps on every change so the card animates

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deck == null) _load();
  }

  Future<void> _load() async {
    final s = Strings.of(context);
    final repo = widget.repository ?? ContentRepository();
    final all = await repo.load(widget.mode, s.code);
    if (!mounted) return;
    setState(() {
      _deck =
          all
              .where(
                (p) => widget.category == null || p.category == widget.category,
              )
              .toList()
            ..shuffle();
    });
  }

  void _next() {
    setState(() {
      _turn++;
      _cardKey++;
      _index = (_index + 1) % _deck!.length;
      if (_index == 0) _deck!.shuffle();
    });
    // TODO(ads): show interstitial every N rounds, between rounds only.
  }

  /// Truth or Dare: swap the current prompt for one of the other kind.
  void _changeType() {
    final deck = _deck!;
    final current = deck[_index].kind;
    for (var step = 1; step < deck.length; step++) {
      final i = (_index + step) % deck.length;
      if (deck[i].kind != current) {
        final tmp = deck[_index];
        deck[_index] = deck[i];
        deck[i] = tmp;
        setState(() => _cardKey++);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final mode = widget.mode;
    final deck = _deck;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.modeName(mode)),
        backgroundColor: Colors.transparent,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: deck == null
              ? const Center(child: CircularProgressIndicator())
              : deck.isEmpty
              ? Center(child: Text(s['empty']))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.group_outlined, size: 18),
                        label: Text(
                          s.playerOf(
                            _turn % widget.players + 1,
                            widget.players,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _PromptCard(
                            key: ValueKey(_cardKey),
                            prompt: deck[_index],
                            accent: mode.color,
                            strings: s,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _next,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            s['next'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (mode == GameMode.truthOrDare) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.tonalIcon(
                            onPressed: _changeType,
                            icon: const Icon(Icons.shuffle_rounded),
                            label: Text(s['change_type']),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    super.key,
    required this.prompt,
    required this.accent,
    required this.strings,
  });

  final Prompt prompt;
  final Color accent;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 26, fontWeight: FontWeight.w700);
    final kind = prompt.kind;
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kind != null) ...[
                    Chip(
                      avatar: Icon(
                        kind == 'truth'
                            ? Icons.chat_bubble_outline
                            : Icons.bolt_rounded,
                        color: accent,
                        size: 18,
                      ),
                      label: Text(
                        strings[kind],
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(prompt.text, textAlign: TextAlign.center, style: style),
                  if (prompt.optionB != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        strings['or'],
                        style: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      prompt.optionB!,
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
