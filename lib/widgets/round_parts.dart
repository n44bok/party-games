import 'package:flutter/material.dart';

import 'glass.dart';

/// "Pass the phone to NAME": shown before a player looks at their role.
class PassCard extends StatelessWidget {
  const PassCard({
    super.key,
    required this.name,
    required this.label,
    this.nameKey,
  });

  final String name;
  final String label;
  final Key? nameKey;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 32,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phone_iphone_rounded,
              size: 52,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            GradientText(
              name,
              key: nameKey,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// The countdown: a ring that drains, with the time inside.
class TimerDial extends StatelessWidget {
  const TimerDial({
    super.key,
    required this.seconds,
    required this.total,
    required this.caption,
    required this.highlight,
    this.warning = false,
    this.timerKey,
  });

  final int seconds;
  final int total;
  final String caption;

  /// Time is up.
  final bool highlight;

  /// Time is nearly up: hurry.
  final bool warning;

  final Key? timerKey;

  static String format(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: total == 0 ? 0 : seconds / total,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(
                highlight
                    ? const Color(0xFFFF6A6A)
                    : warning
                    ? const Color(0xFFFFB347)
                    : const Color(0xFFF06FB5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  format(seconds),
                  key: timerKey,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: warning ? FontWeight.w700 : FontWeight.w400,
                    color: highlight
                        ? const Color(0xFFFF9E9E)
                        : warning
                        ? const Color(0xFFFFC46B)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Text filled with the brand gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => brandGradient.createShader(rect),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
