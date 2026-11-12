import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/settings.dart';
import '../data/strings.dart';
import '../purchase/purchase_service.dart';
import '../widgets/glass.dart';
import '../widgets/glass_blob.dart';
import '../widgets/gradient_background.dart';

/// The single Premium offer: one year without ads, as an auto-renewing
/// subscription.
///
/// The price shown comes from the store (in the person's currency). This
/// dollar price is only what is shown when the store cannot be asked.
const premiumPrice = r'$4.99';

/// The pages the subscription screen must link to.
const privacyPolicyUrl =
    'https://n44bok.github.io/party-games/privacy-policy.html';
const termsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

const _gold = [Color(0xFFFFE08A), Color(0xFFFFA83D)];
const _pink = Color(0xFFF06FB5);

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows what came of a purchase or a restore; closes the screen when
  /// Premium is on.
  void _report(BuildContext context, PurchaseResult result) {
    final s = Strings.of(context);
    final navigator = Navigator.of(context);
    switch (result) {
      case PurchaseResult.purchased:
        _say(context, s['premium_thanks']);
        navigator.maybePop();
      case PurchaseResult.restored:
        _say(context, s['premium_restored']);
        navigator.maybePop();
      case PurchaseResult.nothingToRestore:
        _say(context, s['premium_nothing']);
      case PurchaseResult.cancelled:
        break;
      case PurchaseResult.failed:
        _say(context, s['premium_error']);
      case PurchaseResult.unavailable:
        _say(context, s['premium_unavailable']);
    }
  }

  Future<void> _buy(BuildContext context) async {
    final service = PurchaseScope.read(context);
    if (service.busy) return;
    final result = await service.buy();
    if (context.mounted) _report(context, result);
  }

  Future<void> _restore(BuildContext context) async {
    final service = PurchaseScope.read(context);
    if (service.busy) return;
    final result = await service.restore();
    if (context.mounted) _report(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    final store = PurchaseScope.of(context);
    final settings = SettingsScope.of(context);
    final price = store.price ?? premiumPrice;
    final active = settings.adsRemoved;
    final until = settings.premiumUntil;
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
        // clipped; the top inset is padding inside it. The button stays
        // pinned below it so it is always visible.
        child: SafeArea(
          top: false,
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
                        width: 140,
                        height: 128,
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
                            size: 80,
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
                            fontSize: 38,
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
                      const SizedBox(height: 24),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Benefit(s['benefit_no_ads']),
                            const SizedBox(height: 14),
                            _Benefit(s['benefit_packs']),
                            const SizedBox(height: 14),
                            _Benefit(s['benefit_once']),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _OfferCard(
                        title: s['offer_title'],
                        caption: s['offer_caption'],
                        price: price,
                      ),
                      if (active && until != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          s.format('premium_active_until', {
                            'date': MaterialLocalizations.of(context)
                                .formatMediumDate(until),
                          }),
                          key: const Key('premium_active_until'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _gold1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        s.format('premium_terms', {'price': price}),
                        key: const Key('premium_terms'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          _LinkButton(
                            label: s['premium_privacy'],
                            url: privacyPolicyUrl,
                          ),
                          _LinkButton(
                            label: s['premium_eula'],
                            url: termsOfUseUrl,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nothing to do while a purchase is going on.
                    IgnorePointer(
                      ignoring: store.busy,
                      child: Opacity(
                        opacity: store.busy ? 0.6 : 1,
                        child: GradientButton(
                          key: const Key('premium_unlock'),
                          label: active ? s['done'] : s['unlock'],
                          height: 60,
                          onPressed: active
                              ? () => Navigator.of(context).maybePop()
                              : () => _buy(context),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('premium_restore'),
                      onPressed: store.busy ? null : () => _restore(context),
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

/// The one thing on offer, with its price. Not selectable: there is nothing to
/// choose between.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.title,
    required this.caption,
    required this.price,
  });

  final String title;
  final String caption;
  final String price;

  // The tint is blended onto this base by hand (opaque fill): GlassCard
  // paints its border gradient as a solid layer under the fill, which would
  // show through a translucent one.
  static const _base = Color(0xFF1E1334);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 22,
      strokeWidth: 2,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      gradient: LinearGradient(
        colors: [
          Color.alphaBlend(_pink.withValues(alpha: 0.24), _base),
          Color.alphaBlend(
            const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            _base,
          ),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [
          _pink.withValues(alpha: 0.95),
          const Color(0xFF8B5CF6).withValues(alpha: 0.7),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, size: 32, color: _gold1),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            key: const Key('premium_price'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

const _gold1 = Color(0xFFFFC857);

/// A small underlined link that opens [url] in the browser.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Could not open $url: $e');
        }
      },
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          decoration: TextDecoration.underline,
          color: Color(0xFFC9A8FF),
        ),
      ),
    );
  }
}
