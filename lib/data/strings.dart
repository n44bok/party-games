import 'package:flutter/widgets.dart';

import '../models/game_mode.dart';

/// Minimal localization; swap for gen-l10n once the string count grows.
class Strings {
  Strings(this.code);

  factory Strings.of(BuildContext context) => Strings(
    supported.contains(Localizations.localeOf(context).languageCode)
        ? Localizations.localeOf(context).languageCode
        : 'en',
  );

  static const supported = ['en', 'uk'];

  final String code;

  static const _t = {
    'en': {
      'title': 'Party Games',
      'subtitle': 'Pick a game for your group',
      'next': 'Next',
      'truth': 'Truth',
      'dare': 'Dare',
      'or': 'OR',
      'would_you_rather': 'Would You Rather',
      'most_likely': 'Most Likely To',
      'truth_or_dare': 'Truth or Dare',
      'empty': 'No content available',
      'all': 'All',
      'friends': 'Friends',
      'party': 'Party',
      'funny': 'Funny',
    },
    'uk': {
      'title': 'Ігри для компанії',
      'subtitle': 'Обери гру для своєї компанії',
      'next': 'Далі',
      'truth': 'Правда',
      'dare': 'Дія',
      'or': 'АБО',
      'would_you_rather': 'Що б ти обрав',
      'most_likely': 'Хто найімовірніше',
      'truth_or_dare': 'Правда чи дія',
      'empty': 'Немає контенту',
      'all': 'Усі',
      'friends': 'Друзі',
      'party': 'Вечірка',
      'funny': 'Смішне',
    },
  };

  String operator [](String key) => _t[code]![key] ?? key;

  String modeName(GameMode m) => this[m.id];
}
