import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/glass.dart';
import '../widgets/rules_popover.dart';
import '../widgets/gradient_background.dart';
import 'setup_screen.dart';

/// Shell with the bottom navigation: Home / Favorites / Packs / Stats.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _tab,
            children: [
              const _GamesTab(),
              _ComingSoonTab(
                icon: Icons.favorite_border,
                title: s['favorites'],
              ),
              _ComingSoonTab(icon: Icons.layers_outlined, title: s['packs']),
              _ComingSoonTab(icon: Icons.bar_chart_rounded, title: s['stats']),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: s['home'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: s['favorites'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.layers_outlined),
            selectedIcon: const Icon(Icons.layers),
            label: s['packs'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: s['stats'],
          ),
        ],
      ),
    );
  }
}

class _GamesTab extends StatelessWidget {
  const _GamesTab();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    void comingSoon() =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s['coming_soon'])));

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
              IconButton.filledTonal(
                tooltip: 'Premium',
                onPressed: comingSoon,
                icon: const Icon(Icons.workspace_premium, color: Colors.amber),
              ),
              IconButton.filledTonal(
                tooltip: 'Settings',
                onPressed: comingSoon,
                icon: const Icon(Icons.settings_outlined),
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
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.3,
              children: [
                for (final mode in GameMode.values)
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
            ),
          ),
          // TODO(ads): banner placeholder goes here.
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

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.headlineSmall),
          Text(s['coming_soon']),
        ],
      ),
    );
  }
}
