import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../widgets/glass.dart';
import '../widgets/glass_blob.dart';
import '../widgets/gradient_background.dart';

/// Premium offers shown on the paywall.
///
/// MOCK: the prices are placeholders and nothing can be bought yet.
// TODO(iap): replace with products from in_app_purchase, using the store's
// localized prices and the real product ids.
enum PremiumPlan {
  monthly('monthly', r'$2.99', 'per_month'),
  yearly('yearly', r'$14.99', 'per_year'),
  lifetime('lifetime', r'$24.99', 'one_time');

  const PremiumPlan(this.id, this.price, this.periodKey);

  /// Also the suffix of the plan's name key (`plan_<id>`).
  final String id;
  final String price;
  final String periodKey;

  /// The one we want people to pick.
  bool get isBestValue => this == yearly;
}

const _gold = [Color(0xFFFFE08A), Color(0xFFFFA83D)];

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  PremiumPlan _selected = PremiumPlan.yearly;

  void _unavailable() {
    final s = Strings.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s['premium_unavailable'])));
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
        ),
      ),
      body: GradientBackground(
        dark: true,
        // The scroll view reaches the screen edge so the blob's glow is not
        // clipped; the top inset is padding inside it.
        child: SafeArea(
          top: false,
          // The scroll view reaches the screen edge (see above); the button
          // stays pinned below it so it is always visible.
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.paddingOf(context).top,
                    20,
                    16,
                  ),
                  child: Column(
                    children: [
                      GlassBlob(
                        width: 112,
                        height: 104,
                        fill: const [Color(0xFFFFB35C), Color(0xFF8A4FD0)],
                        glow: const Color(0xFFFFA83D),
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (rect) => const LinearGradient(
                            colors: _gold,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(rect),
                          child: const Icon(
                            Icons.workspace_premium,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (rect) => const LinearGradient(
                          colors: _gold,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(rect),
                        child: Text(
                          s['premium_title'],
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['premium_subtitle'],
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Benefit(s['benefit_no_ads']),
                            const SizedBox(height: 12),
                            _Benefit(s['benefit_packs']),
                            const SizedBox(height: 12),
                            _Benefit(s['benefit_support']),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final plan in PremiumPlan.values) ...[
                        _PlanCard(
                          key: ValueKey('plan_${plan.id}'),
                          plan: plan,
                          selected: plan == _selected,
                          strings: s,
                          onTap: () => setState(() => _selected = plan),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GradientButton(
                      label: s['continue'],
                      height: 60,
                      onPressed: _unavailable,
                    ),
                    TextButton(
                      onPressed: _unavailable,
                      child: Text(
                        s['restore'],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: brandGradient,
          ),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.strings,
    required this.onTap,
  });

  final PremiumPlan plan;
  final bool selected;
  final Strings strings;
  final VoidCallback onTap;

  static const _pink = Color(0xFFF06FB5);
  static const _selectedBase = Color(0xFF1E1334);

  @override
  Widget build(BuildContext context) {
    final s = strings;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Semantics(
            button: true,
            selected: selected,
            child: GlassCard(
              radius: 22,
              strokeWidth: selected ? 2 : GlassCard.borderWidth,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              // Opaque on purpose: GlassCard paints its border gradient as a
              // solid layer under the fill, which shows through any
              // translucent fill. The tint is blended onto the dark base here.
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        Color.alphaBlend(
                          _pink.withValues(alpha: 0.24),
                          _selectedBase,
                        ),
                        Color.alphaBlend(
                          const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          _selectedBase,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderGradient: selected
                  ? LinearGradient(
                      colors: [
                        _pink.withValues(alpha: 0.95),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.38),
                        Colors.white.withValues(alpha: 0.07),
                        Colors.white.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              child: Row(
                children: [
                  _Radio(selected: selected),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['plan_${plan.id}'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (plan.isBestValue)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              s['save_percent'],
                              style: const TextStyle(
                                color: Color(0xFFFFC857),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        plan.price,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        s[plan.periodKey],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (plan.isBestValue)
          Positioned(
            top: -11,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: brandGradient,
              ),
              child: Text(
                s['best_value'],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Round radio indicator; filled with a check when selected.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? brandGradient : null,
        border: selected
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.6,
              ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              key: Key('plan_check'),
              size: 18,
              color: Colors.white,
            )
          : null,
    );
  }
}
