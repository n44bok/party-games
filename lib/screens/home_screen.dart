import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';
import '../widgets/glass.dart';
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.title,
    required this.onTap,
  });

  final GameMode mode;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Ink paints on the nearest Material; without this one it would paint on
    // the Scaffold's, i.e. underneath GradientBackground, and be invisible.
    // The glow lives outside Ink: Ink clips its decoration to its own bounds,
    // which would cut a shadow into a rectangle.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: mode.colors.first.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: mode.colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Stack(
              children: [
                // Glossy highlight along the top edge.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 56,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
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
                        Icon(mode.icon, size: 38, color: Colors.white),
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
              ],
            ),
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
