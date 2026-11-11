import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_games/data/content_repository.dart';
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
}
