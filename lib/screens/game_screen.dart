import 'package:flutter/material.dart';

import '../data/content_repository.dart';
import '../data/content_scope.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/glass.dart';
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
    final repo = widget.repository ?? ContentScope.of(context);
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
      appBar: AppBar(title: Text(s.modeName(mode))),
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
                      GlassCard(
                        radius: 24,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              s.playerOf(
                                _turn % widget.players + 1,
                                widget.players,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _PromptCard(
                            key: ValueKey(_cardKey),
                            prompt: deck[_index],
                            strings: s,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        label: s['next'],
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: _next,
                      ),
                      if (mode == GameMode.truthOrDare) ...[
                        const SizedBox(height: 12),
                        GlassButton(
                          label: s['change_type'],
                          icon: Icons.shuffle_rounded,
                          onPressed: _changeType,
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
  const _PromptCard({super.key, required this.prompt, required this.strings});

  final Prompt prompt;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    const accent = Color(0xFFF0A6F5);
    final kind = prompt.kind;
    return SizedBox.expand(
      child: GlassCard(
        radius: 32,
        padding: const EdgeInsets.all(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            const Color(0xFFB45CF5).withValues(alpha: 0.28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind != null) ...[
                  GlassCard(
                    radius: 22,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          kind == 'truth'
                              ? Icons.chat_bubble_outline
                              : Icons.bolt_rounded,
                          color: accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings[kind],
                          style: const TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(prompt.text, textAlign: TextAlign.center, style: style),
                if (prompt.optionB != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      strings['or'],
                      style: const TextStyle(
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
    );
  }
}
