import 'dart:math';

/// A secret role in Mafia.
enum MafiaRole {
  mafia('mafia'),
  doctor('doctor'),
  detective('detective'),
  citizen('citizen');

  const MafiaRole(this.id);

  /// Also the suffix of the Strings keys (`role_<id>`, `role_<id>_hint`).
  final String id;

  String get nameKey => 'role_$id';
  String get hintKey => 'role_${id}_hint';

  bool get isMafia => this == mafia;
}

/// One round of Mafia: who has which secret role.
///
/// Pure logic with an injectable [Random], so it can be tested.
class MafiaRound {
  MafiaRound._({required this.roles, required this.firstSpeaker});

  /// Deals the roles: [mafia] mafia members, optionally a doctor and a
  /// detective, and citizens for everyone else.
  factory MafiaRound.start({
    required int players,
    required int mafia,
    bool doctor = true,
    bool detective = true,
    Random? random,
  }) {
    assert(mafia >= 1 && mafia <= maxMafiaFor(players));
    final special = (doctor ? 1 : 0) + (detective ? 1 : 0);
    assert(mafia + special < players, 'at least one citizen is needed');
    final rng = random ?? Random();
    final roles = <MafiaRole>[
      for (var i = 0; i < mafia; i++) MafiaRole.mafia,
      if (doctor) MafiaRole.doctor,
      if (detective) MafiaRole.detective,
    ];
    while (roles.length < players) {
      roles.add(MafiaRole.citizen);
    }
    roles.shuffle(rng);
    return MafiaRound._(roles: roles, firstSpeaker: rng.nextInt(players));
  }

  /// Fewest players Mafia is worth playing with.
  static const minPlayers = 5;

  /// The most mafia members that still leave them a minority (and 1 at
  /// minimum). With both special roles in play, there is still a citizen left
  /// from five players on.
  static int maxMafiaFor(int players) => max(1, (players - 1) ~/ 2);

  /// The role of each player, in turn order.
  final List<MafiaRole> roles;

  /// Position of the player who speaks first in the day discussion.
  final int firstSpeaker;

  MafiaRole roleOf(int player) => roles[player];

  /// Turn-order positions of the mafia members.
  List<int> get mafiaIndexes => [
    for (var i = 0; i < roles.length; i++)
      if (roles[i].isMafia) i,
  ];

  /// How many players have [role].
  int count(MafiaRole role) => roles.where((r) => r == role).length;
}
