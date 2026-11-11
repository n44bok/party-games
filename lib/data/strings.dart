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
      'settings': 'Settings',
      'language': 'Language',
      'language_system': 'System default',
      'vibration': 'Vibration',
      'vibration_desc': 'A light tap when the card changes',
      'rules': 'Rules',
      'truth_or_dare_rules': 'Players take turns. Each card is a Truth (a question to answer honestly) or a Dare (a task to perform). Not feeling it? Tap Change Type to get the other kind.',
      'most_likely_rules': 'A question appears. Everyone points at the person it fits best. The one with the most fingers pointed at them owns it and tells the story behind it.',
      'never_have_i_ever_rules': 'Everyone holds up five fingers. If you have done what the card says, put a finger down. The last one with fingers up wins.',
      'this_or_that_rules': 'Two options appear. Everyone picks one at the same time, then explains the choice. No sitting on the fence!',
      'would_you_rather_rules': 'Two tough options appear. Choose one, no skipping, and defend your answer to the group.',
      'random_challenge_rules': 'A mix of every game. Each turn brings a random card, so be ready for anything.',
      'load_error': 'Could not load content',
      'retry': 'Try again',
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
      'player_n': 'Player {n}',
      'name_hint': 'Name (optional)',
      'all': 'All',
      'friends': 'Friends',
      'party': 'Party',
      'funny': 'Funny',
    },
    'uk': {
      'title': 'Party Games', // the app name is not translated
      'subtitle': 'Найкращі ігри для друзів,\nпар і вечірок',
      'next': 'Далі',
      'truth': 'Правда',
      'dare': 'Дія',
      'or': 'АБО',
      'would_you_rather': 'Що б ти обрав',
      'most_likely': 'Хто найімовірніше',
      'truth_or_dare': 'Правда чи дія',
      'empty': 'Немає контенту',
      'settings': 'Налаштування',
      'language': 'Мова',
      'language_system': 'Як у системі',
      'vibration': 'Вібрація',
      'vibration_desc': 'Легка вібрація при зміні картки',
      'rules': 'Правила',
      'truth_or_dare_rules': 'Гравці ходять по черзі. Кожна картка це Правда (запитання, на яке треба відповісти чесно) або Дія (завдання, яке треба виконати). Не підходить? Натисни «Змінити тип», щоб отримати інший вид.',
      'most_likely_rules': 'Показується запитання. Усі вказують на того, кому воно пасує найбільше. Кого вказали найчастіше, той розповідає історію за цим.',
      'never_have_i_ever_rules': 'Усі піднімають по п’ять пальців. Якщо ти робив(ла) те, що написано на картці, загни один палець. Виграє той, у кого пальці лишились найдовше.',
      'this_or_that_rules': 'Показано два варіанти. Усі одночасно обирають один і пояснюють свій вибір. Ухилятися не можна!',
      'would_you_rather_rules': 'Показано два складні варіанти. Обери один, без пропусків, і поясни групі свій вибір.',
      'random_challenge_rules': 'Мікс усіх ігор. Щоразу випадкова картка, тож будь готовий до всього.',
      'load_error': 'Не вдалося завантажити контент',
      'retry': 'Спробувати ще раз',
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
      'player_n': 'Гравець {n}',
      'name_hint': 'Ім\'я (необов\'язково)',
      'all': 'Усі',
      'friends': 'Друзі',
      'party': 'Вечірка',
      'funny': 'Смішне',
    },
  };

  String operator [](String key) => _t[code]![key] ?? key;

  String modeName(GameMode m) => this[m.id];

  /// Default name for player [n] (1-based), e.g. "Player 2".
  String defaultPlayerName(int n) => this['player_n'].replaceAll('{n}', '$n');
}
