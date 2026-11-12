import 'dart:math';

/// A small question only a person is expected to answer: "7 + 4 = ?".
///
/// This is a check on the phone itself. It keeps accidental and lazy abuse
/// out; real protection against spam is the form service's job.
class MathCaptcha {
  MathCaptcha([Random? random]) : _random = random ?? Random() {
    _next();
  }

  final Random _random;
  late int a;
  late int b;

  void _next() {
    a = 2 + _random.nextInt(8);
    b = 2 + _random.nextInt(8);
  }

  /// A new question.
  void refresh() => _next();

  int get answer => a + b;

  /// Whether [typed] is the right answer (spaces are ignored).
  bool accepts(String typed) => int.tryParse(typed.trim()) == answer;
}

/// A rough check that [text] looks like an e-mail address. Empty is fine: the
/// address is optional.
bool looksLikeEmail(String text) {
  final value = text.trim();
  if (value.isEmpty) return true;
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value);
}
