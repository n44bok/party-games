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
  static const _pink = Color(0xFFF06FB5);
  static const _radius = 34.0;

  /// How far the wave reaches below the card's bottom edge.
  static const _waveOverhang = 46.0;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 30,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final kind = prompt.kind;
    // The wave spills out of the card's bottom edge, so it lives outside the
    // card's clip.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GlassCard(
            radius: _radius,
            padding: EdgeInsets.zero,
            // Dark glass; the colored glows are layered on top below.
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1B1031).withValues(alpha: 0.62),
                const Color(0xFF1B1031).withValues(alpha: 0.62),
              ],
            ),
            borderGradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0.06),
                _pink.withValues(alpha: 0.55),
              ],
              stops: const [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                _radius - GlassCard.borderWidth,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Violet glow, top-left.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.9, -1.0),
                        radius: 1.0,
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.38),
                          const Color(0xFF8B5CF6).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  // Pink glow, bottom-right.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(1.0, 1.0),
                        radius: 0.95,
                        colors: [
                          _pink.withValues(alpha: 0.55),
                          _pink.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 56,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          // Without a Truth/Dare badge the text sits in the
                          // middle of the card.
                          mainAxisAlignment: kind == null
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            if (kind != null) ...[
                              _KindBadge(kind: kind, label: strings[kind]),
                              const SizedBox(height: 32),
                            ],
                            Text(
                              prompt.text,
                              textAlign: TextAlign.center,
                              style: style,
                            ),
                            if (prompt.optionB != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
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
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: -_waveOverhang,
          height: 150,
          child: IgnorePointer(
            child: ClipPath(
              clipper: _WaveClipper(_radius, _waveOverhang),
              child: CustomPaint(painter: _WavePainter()),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Truth" / "Dare" badge: violet glass with a lavender-to-pink border.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.label});

  final String kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      gradient: LinearGradient(
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.5),
          const Color(0xFF3A2470).withValues(alpha: 0.55),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [
          _PromptCard._accent.withValues(alpha: 0.8),
          _PromptCard._accent.withValues(alpha: 0.15),
          _PromptCard._pink.withValues(alpha: 0.5),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kind == 'truth'
                ? Icons.chat_bubble_outline_rounded
                : Icons.bolt_rounded,
            color: _PromptCard._pink,
            size: 26,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the wave inside the card's rounded corners while letting it hang
/// freely below the card's bottom edge.
class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper(this.radius, this.overhang);

  final double radius;
  final double overhang;

  @override
  Path getClip(Size size) {
    final cardBottom = size.height - overhang;
    final card = Path()
      ..addRRect(
        RRect.fromLTRBR(
          0,
          -size.height,
          size.width,
          cardBottom,
          Radius.circular(radius),
        ),
      );
    final below = Path()
      ..addRect(Rect.fromLTRB(0, cardBottom, size.width, size.height));
    return Path.combine(PathOperation.union, card, below);
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.overhang != overhang;
}

/// A translucent ribbon that rises from below the card's bottom edge on the
/// left and sweeps up into the card on the right.
class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Path curve(double dy) => Path()
      ..moveTo(w * 0.04, h * 0.74 + dy)
      ..cubicTo(
        w * 0.36,
        h * 0.80 + dy,
        w * 0.6,
        h * 0.30 + dy,
        w,
        h * 0.38 + dy,
      );

    final top = curve(0);
    final bottom = curve(h * 0.17);
    final ribbon = Path.from(top)
      ..lineTo(w, h * 0.38 + h * 0.17)
      ..cubicTo(
        w * 0.6,
        h * 0.30 + h * 0.17,
        w * 0.36,
        h * 0.80 + h * 0.17,
        w * 0.04,
        h * 0.74 + h * 0.17,
      )
      ..close();

    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.0),
            const Color(0xFFD59BFF).withValues(alpha: 0.10),
            const Color(0xFFF06FB5).withValues(alpha: 0.26),
          ],
          stops: const [0.0, 0.18, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.28),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(top, line);
    canvas.drawPath(bottom, line..strokeWidth = 0.8);
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
