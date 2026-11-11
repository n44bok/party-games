import 'dart:math';

/// One round of Spy: who is the spy and where is everyone.
///
/// Pure logic with an injectable [Random], so it can be tested.
class SpyRound {
  SpyRound._({
    required this.location,
    required this.spyIndexes,
    required this.firstAsker,
  });

  /// Starts a round: picks the place, the spies and who asks first.
  ///
  /// [players] is the number of players and [spies] how many are spies. The
  /// spies must be a minority, otherwise the game is not worth playing.
  factory SpyRound.start({
    required int players,
    required int spies,
    required List<String> locations,
    Random? random,
  }) {
    assert(locations.isNotEmpty, 'need at least one location');
    assert(spies >= 1 && spies <= maxSpiesFor(players));
    final rng = random ?? Random();
    final indexes = List<int>.generate(players, (i) => i)..shuffle(rng);
    return SpyRound._(
      location: locations[rng.nextInt(locations.length)],
      spyIndexes: indexes.take(spies).toSet(),
      firstAsker: rng.nextInt(players),
    );
  }

  /// The most spies that still leave them a minority (and 1 at minimum).
  /// Two spies need at least five players.
  static int maxSpiesFor(int players) => max(1, (players - 1) ~/ 2);

  /// The secret place everyone but the spies knows.
  final String location;

  /// Positions (in turn order) of the spies.
  final Set<int> spyIndexes;

  /// Position of the player who asks the first question.
  final int firstAsker;

  bool isSpy(int player) => spyIndexes.contains(player);
}
