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

/// The final scores: a headline, then the players from best to worst with
/// a cup for the winner(s).
class ResultBoard extends StatelessWidget {
  const ResultBoard({
    super.key,
    required this.title,
    required this.titleKey,
    required this.subtitle,
    required this.names,
    required this.scores,
    required this.winners,
    required this.scoreKey,
  });

  final String title;
  final Key titleKey;
  final String subtitle;
  final List<String> names;
  final List<int> scores;

  /// Positions of the winners (several when it is a tie).
  final List<int> winners;

  /// The key of the score text of player `i`.
  final Key Function(int i) scoreKey;

  @override
  Widget build(BuildContext context) {
    final order = [for (var i = 0; i < names.length; i++) i]
      ..sort((a, b) {
        final byScore = scores[b].compareTo(scores[a]);
        return byScore != 0 ? byScore : a.compareTo(b);
      });
    return Column(
      children: [
        GradientText(
          title,
          key: titleKey,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final i in order)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          if (winners.contains(i))
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFFFC043),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              names[i],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${scores[i]}',
                            key: scoreKey(i),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
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
      ],
    );
  }
}
