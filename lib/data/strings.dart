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
      'subtitle': 'The best games for friends,\ncouples and parties',
      'next': 'Next',
      'truth': 'Truth',
      'dare': 'Dare',
      'or': 'OR',
      'would_you_rather': 'Would You Rather',
      'most_likely': 'Most Likely To',
      'truth_or_dare': 'Truth or Dare',
      'empty': 'No content available',
      'packs': 'Packs',
      'truth_or_dare_desc': 'Answer honestly or take on a dare!',
      'most_likely_desc': 'Point at who fits the question best',
      'never_have_i_ever_desc': 'Admit what you have already done',
      'this_or_that_desc': 'Pick one, no overthinking',
      'would_you_rather_desc': 'Choose the lesser evil',
      'random_challenge_desc': 'A surprise from every game',
      'this_or_that': 'This or That',
      'random_challenge': 'Random Challenge',
      'home': 'Home',
      'favorites': 'Favorites',
      'stats': 'Stats',
      'coming_soon': 'Coming soon',
      'never_have_i_ever': 'Never Have I Ever',
      'players': 'Players',
      'category': 'Mode',
      'start': 'Start Game',
      'change_type': 'Change Type',
      'player_of': 'Player {n} of {total}',
      'all': 'All',
      'friends': 'Friends',
      'party': 'Party',
      'funny': 'Funny',
    },
    'uk': {
      'title': 'Ігри для компанії',
      'subtitle': 'Найкращі ігри для друзів,\nпар і вечірок',
      'next': 'Далі',
      'truth': 'Правда',
      'dare': 'Дія',
      'or': 'АБО',
      'would_you_rather': 'Що б ти обрав',
      'most_likely': 'Хто найімовірніше',
      'truth_or_dare': 'Правда чи дія',
      'empty': 'Немає контенту',
      'packs': 'Набори',
      'truth_or_dare_desc': 'Відповідай чесно або виконуй завдання!',
      'most_likely_desc': 'Вкажіть на того, кому це пасує найбільше',
      'never_have_i_ever_desc': 'Зізнайся, що ти вже робив(ла)',
      'this_or_that_desc': 'Обери одне, без довгих роздумів',
      'would_you_rather_desc': 'Обери менше зло',
      'random_challenge_desc': 'Сюрприз із кожної гри',
      'this_or_that': 'Це чи те',
      'random_challenge': 'Випадковий виклик',
      'home': 'Головна',
      'favorites': 'Обране',
      'stats': 'Статистика',
      'coming_soon': 'Скоро буде',
      'never_have_i_ever': 'Я ніколи не…',
      'players': 'Гравці',
      'category': 'Режим',
      'start': 'Почати гру',
      'change_type': 'Змінити тип',
      'player_of': 'Гравець {n} з {total}',
      'all': 'Усі',
      'friends': 'Друзі',
      'party': 'Вечірка',
      'funny': 'Смішне',
    },
  };

  String operator [](String key) => _t[code]![key] ?? key;

  String modeName(GameMode m) => this[m.id];

  String playerOf(int n, int total) =>
      this['player_of'].replaceAll('{n}', '$n').replaceAll('{total}', '$total');
}
