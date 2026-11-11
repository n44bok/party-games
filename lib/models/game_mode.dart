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
    Color(0xFFFF6B8B),
    Color(0xFFE0366F),
  ]),
  mostLikely('most_likely', Icons.help_outline_rounded, [
    Color(0xFFA06CF5),
    Color(0xFF6C3FD8),
  ]),
  neverHaveIEver('never_have_i_ever', Icons.back_hand_outlined, [
    Color(0xFFFFB531),
    Color(0xFFF28A0C),
  ]),
  thisOrThat('this_or_that', Icons.shuffle_rounded, [
    Color(0xFF5BA8FF),
    Color(0xFF3566E0),
  ]),
  wouldYouRather('would_you_rather', Icons.style_rounded, [
    Color(0xFF3FC98B),
    Color(0xFF1E9E63),
  ]),
  randomChallenge('random_challenge', Icons.casino_rounded, [
    Color(0xFFB79CF7),
    Color(0xFF8A6AE6),
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
