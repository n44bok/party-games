import 'dart:math';

/// One round of Spy: who is the spy and what is the secret word.
///
/// Pure logic with an injectable [Random], so it can be tested.
class SpyRound {
  SpyRound._({
    required this.word,
    required this.spyIndexes,
    required this.firstAsker,
  });

  /// Starts a round: picks the secret word, the spies and who asks first.
  ///
  /// [players] is the number of players and [spies] how many are spies. The
  /// spies must be a minority, otherwise the game is not worth playing.
  factory SpyRound.start({
    required int players,
    required int spies,
    required List<String> words,
    Random? random,
  }) {
    assert(words.isNotEmpty, 'need at least one word');
    assert(spies >= 1 && spies <= maxSpiesFor(players));
    final rng = random ?? Random();
    final indexes = List<int>.generate(players, (i) => i)..shuffle(rng);
    return SpyRound._(
      word: words[rng.nextInt(words.length)],
      spyIndexes: indexes.take(spies).toSet(),
      firstAsker: rng.nextInt(players),
    );
  }

  /// The most spies that still leave them a minority (and 1 at minimum).
  /// Two spies need at least five players.
  static int maxSpiesFor(int players) => max(1, (players - 1) ~/ 2);

  /// The secret word (a place, a food, ...) everyone but the spies knows.
  final String word;

  /// Positions (in turn order) of the spies.
  final Set<int> spyIndexes;

  /// Position of the player who asks the first question.
  final int firstAsker;

  bool isSpy(int player) => spyIndexes.contains(player);
}

/// The theme of the secret words.
///
/// Most categories ship with the app: their [id] is the key in
/// `spy_words.json`. [single] is the players' own: one word typed for this
/// game only, never saved.
enum SpyCategory {
  places('places'),
  food('food'),
  animals('animals'),
  jobs('jobs'),
  sports('sports'),
  countries('countries'),
  transport('transport'),
  objects('objects'),
  clothes('clothes'),
  nature('nature'),
  music('music'),
  school('school'),
  body('body'),
  fantasy('fantasy'),
  hobbies('hobbies'),
  kitchen('kitchen'),
  holidays('holidays'),
  city('city'),
  space('space'),
  sea('sea'),
  single('single');

  const SpyCategory(this.id);

  final String id;

  /// One word typed by the players for this game.
  bool get isSingle => this == single;

  /// Strings key of the category's name.
  String get labelKey => 'spy_cat_$id';

  /// The categories whose words come with the app.
  static List<SpyCategory> get builtIn => [
    for (final c in values)
      if (!c.isSingle) c,
  ];
}

/// The words a round may be drawn from: those of the chosen [categories] (read
/// from [byCategory]) and, if [SpyCategory.single] is chosen, the players'
/// [ownWord]. Repeats (a word can belong to several categories) are removed.
List<String> spyWordPool({
  required Set<SpyCategory> categories,
  required Map<String, List<String>> byCategory,
  String? ownWord,
}) {
  final pool = <String>{}; // keeps insertion order
  for (final category in SpyCategory.values) {
    if (!categories.contains(category) || category.isSingle) continue;
    pool.addAll(byCategory[category.id] ?? const []);
  }
  if (categories.contains(SpyCategory.single) && ownWord != null) {
    pool.add(ownWord);
  }
  return pool.toList();
}
