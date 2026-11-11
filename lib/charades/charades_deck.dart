import 'dart:math';

/// Hands out the words to act out, in random order and without repeats until
/// every word has been used once.
class CharadesDeck {
  CharadesDeck(List<String> words, {Random? random})
    : assert(words.isNotEmpty, 'need at least one word'),
      _words = List.of(words),
      _random = random ?? Random() {
    _refill();
  }

  final List<String> _words;
  final Random _random;
  final _pile = <String>[];
  String? _last;

  void _refill() {
    _pile
      ..clear()
      ..addAll(_words..shuffle(_random));
    // A reshuffle must not start with the word that was just played.
    if (_pile.length > 1 && _pile.last == _last) {
      final swap = _random.nextInt(_pile.length - 1);
      final t = _pile.last;
      _pile[_pile.length - 1] = _pile[swap];
      _pile[swap] = t;
    }
  }

  /// The next word.
  String next() {
    if (_pile.isEmpty) _refill();
    return _last = _pile.removeLast();
  }
}

/// The players with the highest score (several when it is a tie).
List<int> charadesWinners(List<int> scores) {
  final best = scores.reduce(max);
  return [
    for (var i = 0; i < scores.length; i++)
      if (scores[i] == best) i,
  ];
}
