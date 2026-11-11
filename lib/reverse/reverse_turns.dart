/// A team in Song Backwards: its name and its players.
class ReverseTeam {
  const ReverseTeam(this.name, this.players);

  final String name;
  final List<String> players;
}

/// One turn: a player sings to a teammate, who sings it back, and a player of
/// the same team guesses.
class ReverseTurn {
  const ReverseTurn({
    required this.round,
    required this.team,
    required this.singer,
    required this.imitator,
    required this.guesser,
  });

  /// 1-based.
  final int round;

  /// Position of the team.
  final int team;

  /// Positions of the players inside the team.
  final int singer;
  final int imitator;
  final int guesser;
}

/// The turns of a whole game, in order. In one round every player of every
/// team sings once; the teams take turns (first players of all teams, then
/// second players, and so on).
///
/// Each singer sings to the next player of their team. The one who guesses is
/// the player after that when the team has three or more players (so that
/// they only know the song from what they hear), otherwise the imitator.
List<ReverseTurn> planTurns(List<int> teamSizes, int rounds) {
  assert(teamSizes.every((n) => n >= 2), 'a team needs two players');
  final widest = teamSizes.fold<int>(0, (a, b) => a > b ? a : b);
  return [
    for (var round = 1; round <= rounds; round++)
      for (var k = 0; k < widest; k++)
        for (var team = 0; team < teamSizes.length; team++)
          if (k < teamSizes[team])
            ReverseTurn(
              round: round,
              team: team,
              singer: k,
              imitator: (k + 1) % teamSizes[team],
              guesser: teamSizes[team] >= 3
                  ? (k + 2) % teamSizes[team]
                  : (k + 1) % teamSizes[team],
            ),
  ];
}
