import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/glass.dart';
import '../widgets/rules_popover.dart';
import '../widgets/gradient_background.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

/// The home screen: the grid of games.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.scrollHint = false});

  /// Briefly scroll the games list on first show, so people notice it
  /// scrolls. Off by default; the app turns it on.
  final bool scrollHint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        maxContentWidth: 1000,
        child: SafeArea(child: _GamesTab(scrollHint: scrollHint)),
      ),
    );
  }
}

class _GamesTab extends StatefulWidget {
  const _GamesTab({required this.scrollHint});

  final bool scrollHint;

  @override
  State<_GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<_GamesTab> {
  static const _hintDelay = Duration(milliseconds: 900);
  static const _hintPause = Duration(milliseconds: 250);
  static const _hintRetry = Duration(seconds: 1);
  static const _maxHintAttempts = 4;

  final _scroll = ScrollController();
  Timer? _hintTimer;
  int _hintAttempts = 0;
  bool _hinting = false;
  bool _hintCancelled = false;

  @override
  void initState() {
    super.initState();
    // The state outlives tab switches, so this runs once per app launch.
    if (widget.scrollHint) _hintTimer = Timer(_hintDelay, _playScrollHint);
  }

  /// Scrolls down to the last game and back up, once.
  Future<void> _playScrollHint() async {
    if (!mounted || _hintCancelled || !_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) return; // respect the setting
    final extent = _scroll.position.maxScrollExtent;
    if (extent <= 0) {
      // Everything fits for now. The banner can still arrive and take space,
      // making the list scrollable, so look again a few times.
      if (_hintAttempts++ < _maxHintAttempts) {
        _hintTimer = Timer(_hintRetry, _playScrollHint);
      }
      return;
    }

    final duration = Duration(
      milliseconds: (500 + extent * 1.2).round().clamp(500, 1400),
    );
    _hinting = true;
    try {
      await _scroll.animateTo(
        extent,
        duration: duration,
        curve: Curves.easeInOut,
      );
      if (!mounted || _hintCancelled) return;
      await Future<void>.delayed(_hintPause);
      if (!mounted || _hintCancelled) return;
      await _scroll.animateTo(0, duration: duration, curve: Curves.easeInOut);
    } finally {
      _hinting = false;
    }
  }

  /// The user touched the screen: stop where we are and never start again.
  void _cancelScrollHint() {
    _hintCancelled = true;
    _hintTimer?.cancel();
    if (_hinting && _scroll.hasClients) _scroll.jumpTo(_scroll.offset);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);

    final titleStyle = theme.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.0,
      color: Colors.white,
    );
    final words = s['title'].split(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassIconButton(
                tooltip: s['premium_title'],
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                ),
                icon: Icons.workspace_premium,
                iconColor: const Color(0xFFFFC857),
              ),
              GlassIconButton(
                tooltip: s['settings'],
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: Icons.settings_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(right: -50, top: -24, child: _Cups()),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(words.first, style: titleStyle),
                    ShaderMask(
                      shaderCallback: (rect) =>
                          brandGradient.createShader(rect),
                      child: Text(
                        words.skip(1).join(' '),
                        style: titleStyle?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(s['subtitle'], style: theme.textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Listener(
              onPointerDown: (_) => _cancelScrollHint(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final modes = GameMode.values;
                  // Phones get two columns and scroll. Wider screens get
                  // more columns, sized so that every game fits on screen.
                  final columns = (constraints.maxWidth / 170).floor().clamp(
                    2,
                    5,
                  );
                  var aspect = 1.3;
                  if (columns > 2) {
                    final rows = (modes.length / columns).ceil();
                    final cellWidth =
                        (constraints.maxWidth - 14 * (columns - 1)) / columns;
                    final cellHeight =
                        (constraints.maxHeight - 14 * (rows - 1)) / rows;
                    aspect = (cellWidth / cellHeight).clamp(1.0, 1.6);
                  }
                  return GridView.count(
                    controller: _scroll,
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: aspect,
                    children: [
                      for (final mode in modes)
                        _ModeCard(
                          mode: mode,
                          title: s.modeName(mode),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetupScreen(mode: mode),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Banner under the games; takes no space until an ad has loaded.
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Center(child: AdScope.of(context).buildBanner()),
          ),
        ],
      ),
    );
  }
}

/// Neon cups illustration. The picture has an opaque dark backdrop, so its
/// edges are faded out to blend into the screen's own gradient.
class _Cups extends StatelessWidget {
  const _Cups();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 290,
        height: 200,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const RadialGradient(
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, 0.5, 1.0],
          ).createShader(rect),
          child: Image.asset(
            'assets/images/party_cups.jpg',
            fit: BoxFit.cover,
            // Decorative only; never break the screen over a missing image.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Small "?" in a circle; opens a popover with the game's rules.
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Tooltip(
      message: s['rules'],
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Anchor the popover to this exact button.
          final box = context.findRenderObject()! as RenderBox;
          showRulesPopover(
            context,
            anchor: box.localToGlobal(Offset.zero) & box.size,
            title: s.modeName(mode),
            body: s['${mode.id}_rules'],
          );
        },
        // A roomy touch target around a small visible circle.
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Icon(
              Icons.question_mark_rounded,
              size: 15,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.title,
    required this.onTap,
  });

  final GameMode mode;
  final String title;
  final VoidCallback onTap;

  static const _radius = 22.0;
  static const _border = 1.3;

  @override
  Widget build(BuildContext context) {
    final glow = mode.glow;
    // Outer box paints the gradient border; the inner one is the glass body.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55),
            glow.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.10),
            glow.withValues(alpha: 0.5),
          ],
          stops: const [0.0, 0.35, 0.7, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_border),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius - _border),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dark, slightly see-through glass.
              ColoredBox(
                color: const Color(0xFF140B2B).withValues(alpha: 0.62),
              ),
              // Colored glow entering from a corner.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: mode.glowAlignment,
                    radius: 1.15,
                    colors: [
                      glow.withValues(alpha: 0.75),
                      glow.withValues(alpha: 0.22),
                      glow.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Faint sheen on the top edge.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.4],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(mode.icon, size: 38, color: mode.tint),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
              // Sits above the tap area so it does not open the game.
              Positioned(top: 2, right: 2, child: _HelpButton(mode: mode)),
            ],
          ),
        ),
      ),
    );
  }
}
