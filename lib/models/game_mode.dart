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
  spy('spy', Icons.person_search_rounded, [
    Color(0xFFC6E03A),
    Color(0xFF55661A),
  ]),
  mafia('mafia', Icons.nightlight_round, [
    Color(0xFFC23A52),
    Color(0xFF4A1226),
  ]),
  charades('charades', Icons.theater_comedy_rounded, [
    Color(0xFFF2B84B),
    Color(0xFF8A5A12),
  ]),
  reverseSong('reverse_song', Icons.mic_rounded, [
    Color(0xFF29B6F6),
    Color(0xFF0B4F74),
  ]),
  truthOrDare('truth_or_dare', Icons.local_fire_department, [
    Color(0xFFE8548F),
    Color(0xFF8A2C6B),
  ]),
  mostLikely('most_likely', Icons.help_outline_rounded, [
    Color(0xFF7A4DE0),
    Color(0xFF3A2A8A),
  ]),
  thisOrThat('this_or_that', Icons.shuffle_rounded, [
    Color(0xFF3E86D8),
    Color(0xFF1F3470),
  ]),
  neverHaveIEver('never_have_i_ever', Icons.back_hand_outlined, [
    Color(0xFFD4604E),
    Color(0xFF7A2B45),
  ]),
  randomChallenge('random_challenge', Icons.casino_rounded, [
    Color(0xFFE0A15C),
    Color(0xFF8C5A3C),
  ]),
  wouldYouRather('would_you_rather', Icons.style_rounded, [
    Color(0xFF2BA39B),
    Color(0xFF14505E),
  ]);

  const GameMode(this.id, this.icon, this.colors);

  final String id;
  final IconData icon;
  final List<Color> colors;

  Color get color => colors.last;

  /// Fewest players the game works with.
  int get minPlayers => switch (this) {
    spy => 3,
    mafia => 5,
    reverseSong => 3,
    _ => 2,
  };

  /// Players preselected on the setup screen.
  int get defaultPlayers => switch (this) {
    spy => 3,
    mafia => 6,
    charades => 3,
    reverseSong => 3,
    _ => 2,
  };

  /// Games that show one interstitial ad as the game starts.
  bool get hasStartAd =>
      this == spy || this == mafia || this == charades || this == reverseSong;

  /// Accent that glows in from a corner of the home-screen card.
  Color get glow => switch (this) {
    spy => const Color(0xFFC6E03A),
    mafia => const Color(0xFFFF3B55),
    charades => const Color(0xFFFFC043),
    reverseSong => const Color(0xFF38BDF8),
    truthOrDare => const Color(0xFFFF4F92),
    mostLikely => const Color(0xFF8A5CFF),
    neverHaveIEver => const Color(0xFFFF6A3D),
    thisOrThat => const Color(0xFF3F7BFF),
    wouldYouRather => const Color(0xFF1FB8AE),
    randomChallenge => const Color(0xFFF2A04A),
  };

  /// Where the glow starts inside the card.
  Alignment get glowAlignment => switch (this) {
    mostLikely => const Alignment(0.9, -1.0),
    neverHaveIEver => const Alignment(-0.9, 1.0),
    randomChallenge => const Alignment(0.9, 1.0),
    _ => const Alignment(-0.9, -1.0),
  };

  /// Pastel version of [glow] for the card icon.
  Color get tint => switch (this) {
    spy => const Color(0xFFEEF7A8),
    mafia => const Color(0xFFFFA3AE),
    charades => const Color(0xFFFFE2A3),
    reverseSong => const Color(0xFFA5E3FF),
    truthOrDare => const Color(0xFFFF9EC4),
    mostLikely => const Color(0xFFC9A8FF),
    neverHaveIEver => const Color(0xFFFFB59A),
    thisOrThat => const Color(0xFF9AD4FF),
    wouldYouRather => const Color(0xFFA6EAF2),
    randomChallenge => const Color(0xFFFFE6C8),
  };

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
