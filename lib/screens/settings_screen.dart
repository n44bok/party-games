import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_service.dart';
import '../data/settings.dart';
import '../data/strings.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';
import 'contact_screen.dart';

/// Where people can support the developer.
const paypalDonateUrl = 'https://paypal.me/n44bok';
const koFiUrl = 'https://ko-fi.com/n44bok';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Apple does not allow an app to send people to outside payment pages
  /// (guideline 3.1.1), so the donation links are left out on iPhone. Set this
  /// to `true` there only if Apple's rules change or a tip jar through
  /// in-app purchases replaces them.
  static bool get donationsVisible =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  /// Language choices. A language is always shown in its own language, so
  /// someone who ended up in the wrong one can still find theirs.
  static const _languages = [
    (code: 'en', name: 'English'),
    (code: 'es', name: 'Español'),
    (code: 'pl', name: 'Polski'),
    (code: 'uk', name: 'Українська'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final current = settings.locale?.languageCode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          s['settings'],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
        ),
      ),
      body: GradientBackground(
        dark: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _SectionLabel(s['language']),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _ChoiceRow(
                      label: s['language_system'],
                      selected: current == null,
                      onTap: () => settings.setLocale(null),
                    ),
                    for (final language in _languages) ...[
                      const _RowDivider(),
                      _ChoiceRow(
                        label: language.name,
                        selected: current == language.code,
                        onTap: () => settings.setLocale(Locale(language.code)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _SwitchCard(
                icon: Icons.vibration_rounded,
                title: s['vibration'],
                description: s['vibration_desc'],
                value: settings.haptics,
                onChanged: settings.setHaptics,
                switchKey: const Key('hapticsSwitch'),
              ),
              // Only where consent is required (e.g. the EU) and while ads
              // are on.
              if (!settings.adsRemoved) const _PrivacyOptionsCard(),
              const SizedBox(height: 28),
              _SectionLabel(s['feedback']),
              _NavCard(
                key: const Key('contactCard'),
                icon: Icons.mail_outline_rounded,
                title: s['contact_card_title'],
                description: s['contact_card_desc'],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactScreen()),
                ),
              ),
              if (donationsVisible) ...[
                const SizedBox(height: 28),
                _SectionLabel(s['support']),
                Text(
                  s['support_desc'],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _LinkCard(
                  key: const Key('donatePayPal'),
                  icon: Icons.payments_outlined,
                  title: s['donate_paypal'],
                  url: paypalDonateUrl,
                ),
                const SizedBox(height: 12),
                _LinkCard(
                  key: const Key('donateKofi'),
                  icon: Icons.coffee_outlined,
                  title: s['donate_kofi'],
                  url: koFiUrl,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A card that opens another screen: an icon, a title and a friendly line.
class _NavCard extends StatelessWidget {
  const _NavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card that opens [url] in the browser.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    super.key,
    required this.icon,
    required this.title,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            try {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            } catch (e) {
              debugPrint('Could not open $url: $e');
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                const Icon(Icons.open_in_new_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ad privacy": opens the form where people can change their consent. It
/// shows up only when it is required (the SDK says so).
class _PrivacyOptionsCard extends StatefulWidget {
  const _PrivacyOptionsCard();

  @override
  State<_PrivacyOptionsCard> createState() => _PrivacyOptionsCardState();
}

class _PrivacyOptionsCardState extends State<_PrivacyOptionsCard> {
  bool _required = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AdScope.read(context).privacyOptionsRequired().then((required) {
      if (mounted && required != _required) {
        setState(() => _required = required);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_required) return const SizedBox.shrink();
    final s = Strings.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('privacyOptions'),
            borderRadius: BorderRadius.circular(24),
            onTap: () => AdScope.read(context).showPrivacyOptions(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['ad_privacy'],
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s['ad_privacy_desc'],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card with an icon, a title, a short description and an on/off switch.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.switchKey,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key switchKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFB45CF5),
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 20,
    endIndent: 20,
    color: Colors.white.withValues(alpha: 0.10),
  );
}

/// One selectable row; the chosen one shows a pink check.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Material keeps the ripple above the glass fill (see GradientButton).
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: brandGradient,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
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
