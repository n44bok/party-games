import 'mafia_round.dart';

/// Which side won.
enum MafiaSide { citizens, mafia }

/// The state of a Mafia game after the roles are dealt: who is still in, and
/// what the nights and the votes did.
///
/// Pure logic, so it can be tested without any UI.
class MafiaGame {
  MafiaGame(this.round)
    : _alive = {for (var i = 0; i < round.roles.length; i++) i};

  final MafiaRound round;
  final Set<int> _alive;

  bool isAlive(int player) => _alive.contains(player);

  /// Players still in the game, in turn order.
  List<int> get alive => [
    for (var i = 0; i < round.roles.length; i++)
      if (isAlive(i)) i,
  ];

  /// Living players the mafia may choose from (not their own).
  List<int> get aliveNonMafia => [
    for (final i in alive)
      if (!round.roleOf(i).isMafia) i,
  ];

  int get mafiaAlive => alive.where((i) => round.roleOf(i).isMafia).length;
  int get othersAlive => alive.length - mafiaAlive;

  bool _roleAlive(MafiaRole role) => alive.any((i) => round.roleOf(i) == role);

  bool get doctorAlive => _roleAlive(MafiaRole.doctor);
  bool get detectiveAlive => _roleAlive(MafiaRole.detective);

  /// Ends a night: the mafia chose [victim] and the doctor [saved]. Returns
  /// who was eliminated, or `null` when the doctor saved the victim. A dead
  /// doctor saves nobody (the app still asks, so that nobody can tell).
  int? resolveNight({required int victim, int? saved}) {
    assert(isAlive(victim));
    if (saved == victim && doctorAlive) return null;
    _alive.remove(victim);
    return victim;
  }

  /// The players vote [player] out.
  void voteOut(int player) {
    assert(isAlive(player));
    _alive.remove(player);
  }

  /// Whether [player] is mafia (what the detective finds out).
  bool isMafia(int player) => round.roleOf(player).isMafia;

  /// The winner, or `null` while the game goes on. The citizens win when the
  /// mafia is gone; the mafia win once they are as many as everyone else.
  MafiaSide? get winner {
    if (mafiaAlive == 0) return MafiaSide.citizens;
    if (mafiaAlive >= othersAlive) return MafiaSide.mafia;
    return null;
  }
}
