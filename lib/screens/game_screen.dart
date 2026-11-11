import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
  Object? _error;
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
    try {
      final all = await repo.load(widget.mode, s.code);
      if (!mounted) return;
      setState(() {
        _error = null;
        _deck =
            all
                .where(
                  (p) =>
                      widget.category == null || p.category == widget.category,
                )
                .toList()
              ..shuffle();
      });
    } catch (e, st) {
      debugPrint('Failed to load ${widget.mode.id} (${s.code}): $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load();
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
        centerTitle: true,
        title: Text(
          s.modeName(mode),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(s['coming_soon']))),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: _error != null
              ? _LoadError(
                  message: s['load_error'],
                  details: kDebugMode ? '$_error' : null,
                  retryLabel: s['retry'],
                  onRetry: _retry,
                )
              : deck == null
              ? const Center(child: CircularProgressIndicator())
              : deck.isEmpty
              ? Center(child: Text(s['empty']))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      GlassCard(
                        radius: 30,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group_outlined, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              s.playerOf(
                                _turn % widget.players + 1,
                                widget.players,
                              ),
                              style: const TextStyle(fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        // The card takes most of the free space and leaves a
                        // gap above the buttons, as in the design.
                        child: LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              height: constraints.maxHeight * 0.8,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _PromptCard(
                                  key: ValueKey(_cardKey),
                                  prompt: deck[_index],
                                  strings: s,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        label: s['next'],
                        trailingIcon: Icons.arrow_forward_rounded,
                        height: 64,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B6BF5), Color(0xFFF2709C)],
                        ),
                        onPressed: _next,
                      ),
                      if (mode == GameMode.truthOrDare) ...[
                        const SizedBox(height: 14),
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

  static const _accent = Color(0xFFD59BFF);

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 30,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final kind = prompt.kind;
    return SizedBox.expand(
      child: GlassCard(
        radius: 34,
        padding: EdgeInsets.zero,
        // Violet glow top-left, dark middle, pink glow bottom-right.
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7A4DD8).withValues(alpha: 0.55),
            const Color(0xFF1E1236).withValues(alpha: 0.6),
            const Color(0xFFE0508F).withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // GlassCard doesn't clip its child, so round the wave's corners here.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34 - 1.2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _WavePainter()),
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 56,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      // Without a Truth/Dare badge the text sits in the middle.
                      mainAxisAlignment: kind == null
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        if (kind != null) ...[
                          GlassCard(
                            radius: 28,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  kind == 'truth'
                                      ? Icons.chat_bubble_outline_rounded
                                      : Icons.bolt_rounded,
                                  color: _accent,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  strings[kind],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          prompt.text,
                          textAlign: TextAlign.center,
                          style: style,
                        ),
                        if (prompt.optionB != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              strings['or'],
                              style: const TextStyle(
                                color: _accent,
                                fontSize: 17,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft wave along the bottom of the card.
class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.86)
      ..cubicTo(
        size.width * 0.3,
        size.height * 1.0,
        size.width * 0.6,
        size.height * 0.68,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.10),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.details,
  });

  final String message;
  final String retryLabel;
  final String? details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(details!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            GlassButton(
              label: retryLabel,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
