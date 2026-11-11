import 'package:flutter/material.dart';

/// A single prompt shown to players.
class Prompt {
  const Prompt(this.text, this.category, {this.optionB, this.kind});

  /// Main text (for Would You Rather this is option A).
  final String text;

  final Category category;

  /// Second option, only for Would You Rather.
  final String? optionB;

  /// Sub-type inside a mode, e.g. "truth" / "dare". Also a Strings key.
  final String? kind;
}

enum GameMode {
  truthOrDare('truth_or_dare', Icons.local_fire_department, [
    Color(0xFFE8548F),
    Color(0xFF8A2C6B),
  ]),
  mostLikely('most_likely', Icons.help_outline_rounded, [
    Color(0xFF7A4DE0),
    Color(0xFF3A2A8A),
  ]),
  neverHaveIEver('never_have_i_ever', Icons.back_hand_outlined, [
    Color(0xFFD4604E),
    Color(0xFF7A2B45),
  ]),
  thisOrThat('this_or_that', Icons.shuffle_rounded, [
    Color(0xFF3E86D8),
    Color(0xFF1F3470),
  ]),
  wouldYouRather('would_you_rather', Icons.style_rounded, [
    Color(0xFF2BA39B),
    Color(0xFF14505E),
  ]),
  randomChallenge('random_challenge', Icons.casino_rounded, [
    Color(0xFFE0A15C),
    Color(0xFF8C5A3C),
  ]);

  const GameMode(this.id, this.icon, this.colors);

  final String id;
  final IconData icon;
  final List<Color> colors;

  Color get color => colors.last;

  LinearGradient get gradient => LinearGradient(
    colors: colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Content files that feed this mode.
  List<String> get files => switch (this) {
    truthOrDare => const ['truth', 'dare'],
    // A mix of everything.
    randomChallenge => const [
      'truth',
      'dare',
      'most_likely',
      'never_have_i_ever',
      'this_or_that',
      'would_you_rather',
    ],
    _ => [id],
  };
}

/// Content category; every mode has prompts in each category.
// TODO(ads): mark some categories premium and unlock via rewarded ads.
enum Category {
  friends('friends', Icons.group),
  party('party', Icons.celebration),
  funny('funny', Icons.sentiment_very_satisfied);

  const Category(this.id, this.icon);

  final String id;
  final IconData icon;

  static Category fromId(String id) =>
      values.firstWhere((c) => c.id == id, orElse: () => friends);
}
