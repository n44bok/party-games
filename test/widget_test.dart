import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:party_games/data/content_repository.dart';
import 'package:party_games/data/settings.dart';
import 'package:party_games/main.dart';
import 'package:party_games/models/game_mode.dart';
import 'package:party_games/screens/game_screen.dart';
import 'package:party_games/widgets/category_chips.dart';

/// In-memory content: no asset I/O, so tests are fast and deterministic.
class FakeRepository extends ContentRepository {
  @override
  Future<List<Prompt>> load(GameMode mode, String lang) async => [
    for (final file in mode.files)
      for (final category in Category.values)
        Prompt(
          '$file ${category.id}',
          category,
          optionB: (file == 'would_you_rather' || file == 'this_or_that')
              ? 'other'
              : null,
          kind: (file == 'truth' || file == 'dare') ? file : null,
        ),
  ];
}

/// Remembers which languages content was requested in.
class RecordingRepository extends FakeRepository {
  final languages = <String>[];

  @override
  Future<List<Prompt>> load(GameMode mode, String lang) {
    languages.add(lang);
    return super.load(mode, lang);
  }
}

/// Fails the first `failures` loads, then behaves like [FakeRepository].
class FlakyRepository extends FakeRepository {
  FlakyRepository(this.failures);

  int failures;

  @override
  Future<List<Prompt>> load(GameMode mode, String lang) {
    if (failures-- > 0) throw StateError('boom');
    return super.load(mode, lang);
  }
}

Widget app() => PartyGamesApp(repository: FakeRepository());

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Lets route transitions and the card animation finish. Not pumpAndSettle:
/// in the full-suite run it never settled.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(); // start the transition / animation
  await tester.pump(const Duration(milliseconds: 400)); // finish it
}

/// Text inside the game screen only: the setup screen stays underneath and its
/// name fields show hints like "Player 1".
Finder inGame(String text) =>
    find.descendant(of: find.byType(GameScreen), matching: find.text(text));

/// Scrolls the setup screen to "Start Game" (the name fields push it down)
/// and taps it.
Future<void> startGame(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Start Game'));
  await tester.pump();
  await tester.tap(find.text('Start Game'));
}

/// Pumps until the game screen shows its first prompt. Asset reads finish in
/// real time, which the fake test clock doesn't wait for, so poll for them.
Future<void> loaded(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 400));
    if (find.text('Next').evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  fail('content did not load');
}

void main() {
  testWidgets('home lists all game modes', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    for (final title in [
      'Truth or Dare',
      'Most Likely To',
      'Never Have I Ever',
      'This or That',
      'Would You Rather',
      'Random Challenge',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('bottom navigation switches tabs', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Favorites'));
    await settle(tester);
    expect(find.text('Coming soon'), findsWidgets);
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.text('Party'), findsOneWidget);
  });

  for (final title in [
    'This or That',
    'Random Challenge',
    'Never Have I Ever',
    'Most Likely To',
  ]) {
    testWidgets('$title starts with content', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await tester.tap(find.text(title));
      await settle(tester);
      await startGame(tester);
      await loaded(tester);
      expect(inGame('Player 1'), findsOneWidget);
      expect(find.text('No content available'), findsNothing);
    });
  }

  testWidgets('setup -> game shows player turns', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Would You Rather'));
    await settle(tester);

    // Setup screen: players stepper and categories.
    expect(find.byKey(const Key('playersCount')), findsOneWidget);
    // Scoped: the home screen stays underneath and has its own "Party" title.
    Finder chip(String label) => find.descendant(
      of: find.byType(CategoryChips),
      matching: find.text(label),
    );
    for (final label in ['All', 'Friends', 'Party', 'Funny']) {
      expect(chip(label), findsOneWidget);
    }
    expect(find.text('2'), findsOneWidget); // two players by default
    expect(find.byType(TextField), findsNWidgets(2)); // one name per player
    await tester.tap(find.byTooltip('+'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.tap(chip('Funny'));
    await startGame(tester);
    await loaded(tester);

    expect(inGame('Player 1'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(inGame('Player 2'), findsOneWidget);
  });

  testWidgets('entered names are shown in turn order', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Most Likely To'));
    await settle(tester);

    await tester.tap(find.byTooltip('+')); // 2 -> 3 players
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '  Anna ');
    await tester.enterText(find.byType(TextField).at(1), 'Bohdan');
    // The third field is left empty: falls back to "Player 3".
    await startGame(tester);
    await loaded(tester);

    final order = <String>[];
    for (var i = 0; i < 4; i++) {
      for (final name in ['Anna', 'Bohdan', 'Player 3']) {
        if (inGame(name).evaluate().isNotEmpty) order.add(name);
      }
      await tester.tap(find.text('Next'));
      await settle(tester);
    }
    expect(order, ['Anna', 'Bohdan', 'Player 3', 'Anna']);
  });

  testWidgets('removing a player drops its name field', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Most Likely To'));
    await settle(tester);

    await tester.tap(find.byTooltip('+'));
    await tester.tap(find.byTooltip('+'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(4));

    await tester.enterText(find.byType(TextField).at(3), 'Last');
    await tester.tap(find.byTooltip('−'));
    await tester.pump();
    expect(find.text('Last'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.tap(find.byTooltip('+'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('Last'), findsNothing); // the new field is blank
  });

  testWidgets('there are never fewer than two players', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Most Likely To'));
    await settle(tester);

    await tester.tap(find.byTooltip('−'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('truth or dare can change type', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Truth or Dare'));
    await settle(tester);
    await startGame(tester);
    await loaded(tester);

    final wasTruth = find.text('Truth').evaluate().isNotEmpty;
    await tester.tap(find.text('Change Type'));
    await settle(tester);
    expect(find.text(wasTruth ? 'Dare' : 'Truth'), findsOneWidget);
    // Changing type does not advance the turn.
    expect(inGame('Player 1'), findsOneWidget);
  });

  testWidgets('load failure shows an error and can be retried', (tester) async {
    phone(tester);
    await tester.pumpWidget(PartyGamesApp(repository: FlakyRepository(1)));
    await tester.tap(find.text('Truth or Dare'));
    await settle(tester);
    await startGame(tester);
    await settle(tester);
    await settle(tester);

    expect(find.text('Could not load content'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Try again'));
    await loaded(tester);
    expect(inGame('Player 1'), findsOneWidget);
  });

  testWidgets('help button shows the rules in a popover', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());

    // One help button per game card.
    expect(find.byTooltip('Rules'), findsNWidgets(6));

    // The first card is Truth or Dare; the help button must not open the game.
    await tester.tap(find.byTooltip('Rules').first);
    await settle(tester);
    expect(find.textContaining('Change Type'), findsOneWidget);
    expect(find.text('Start Game'), findsNothing);

    // Tapping outside closes it.
    await tester.tapAt(const Offset(5, 400));
    await settle(tester);
    expect(find.textContaining('Change Type'), findsNothing);
  });

  group('settings', () {
    test('are saved and restored', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await SettingsController.load();
      expect(first.locale, isNull); // follows the system by default
      expect(first.haptics, isTrue);

      await first.setLocale(const Locale('uk'));
      await first.setHaptics(false);

      final second = await SettingsController.load();
      expect(second.locale, const Locale('uk'));
      expect(second.haptics, isFalse);

      await second.setLocale(null); // back to the system language
      expect((await SettingsController.load()).locale, isNull);
    });

    testWidgets('language can be switched from the settings screen', (
      tester,
    ) async {
      phone(tester);
      final settings = SettingsController();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), settings: settings),
      );

      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.text('Settings'), findsWidgets);
      for (final label in ['System default', 'English', 'Українська']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Українська'));
      await settle(tester);
      expect(settings.locale, const Locale('uk'));
      expect(find.text('Налаштування'), findsWidgets);

      // The home screen behind it is translated too.
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('Правда чи дія'), findsOneWidget);
      expect(find.text('Truth or Dare'), findsNothing);
    });

    testWidgets('vibration can be switched off', (tester) async {
      phone(tester);
      final settings = SettingsController();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), settings: settings),
      );
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);

      expect(settings.haptics, isTrue);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(settings.haptics, isFalse);
    });

    testWidgets('changing language in a game reloads the cards', (
      tester,
    ) async {
      phone(tester);
      final repository = RecordingRepository();
      await tester.pumpWidget(
        PartyGamesApp(repository: repository, settings: SettingsController()),
      );
      await tester.tap(find.text('Truth or Dare'));
      await settle(tester);
      await startGame(tester);
      await loaded(tester);
      expect(repository.languages, ['en']);

      // Open settings from the game's gear and switch to Ukrainian.
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await tester.tap(find.text('Українська'));
      await settle(tester);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);

      expect(repository.languages, ['en', 'uk']);
    });
  });

  group('premium', () {
    Finder check(String plan) => find.descendant(
      of: find.byKey(ValueKey('plan_$plan')),
      matching: find.byKey(const Key('plan_check')),
    );

    testWidgets('opens from the header and lists the benefits', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Premium'));
      await settle(tester);

      expect(find.text('Premium'), findsWidgets);
      expect(find.text('No ads'), findsOneWidget);
      for (final plan in ['Monthly', 'Yearly', 'Lifetime']) {
        expect(find.text(plan), findsOneWidget);
      }
      expect(find.text('Best value'), findsOneWidget);
    });

    testWidgets('yearly is preselected and plans can be switched', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Premium'));
      await settle(tester);

      expect(check('yearly'), findsOneWidget);
      expect(check('monthly'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('plan_monthly')));
      await tester.pump();
      expect(check('monthly'), findsOneWidget);
      expect(check('yearly'), findsNothing);
    });

    // Nothing can be bought yet: both actions only tell the user so. (The
    // messenger shows a snack bar on every Scaffold, including the one below,
    // hence findsWidgets.)
    for (final action in ['Continue', 'Restore purchases']) {
      testWidgets('"$action" says purchases are not available yet', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(app());
        await tester.tap(find.byTooltip('Premium'));
        await settle(tester);

        expect(find.text('Purchases will be available soon'), findsNothing);
        await tester.ensureVisible(find.text(action));
        await tester.tap(find.text(action));
        await tester.pump();
        expect(find.text('Purchases will be available soon'), findsWidgets);
      });
    }
  });
}
