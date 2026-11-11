import 'package:flutter/material.dart';

/// A single prompt shown to players.
class Prompt {
  const Prompt(this.text, {this.optionB, this.label});

  /// Main text (for Would You Rather this is option A).
  final String text;

  /// Second option, only for Would You Rather.
  final String? optionB;

  /// Optional badge, e.g. "Truth" / "Dare".
  final String? label;
}

enum GameMode {
  wouldYouRather('would_you_rather', Icons.compare_arrows, Color(0xFF6C63FF)),
  mostLikely('most_likely', Icons.emoji_people, Color(0xFFFF6584)),
  truthOrDare('truth_or_dare', Icons.local_fire_department, Color(0xFFFFA726));

  const GameMode(this.id, this.icon, this.color);

  final String id;
  final IconData icon;
  final Color color;

  /// Content files that feed this mode.
  List<String> get files =>
      this == truthOrDare ? const ['truth', 'dare'] : [id];
}
