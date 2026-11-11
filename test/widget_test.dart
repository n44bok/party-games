import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:party_games/ads/ad_service.dart';
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

/// Counts rounds and shows a recognizable banner.
class FakeAdService implements AdService {
  int games = 0;
  int rounds = 0;

  @override
  void onGameStarted() => games++;

  @override
  Widget buildBanner() => const SizedBox(key: Key('fake_banner'), height: 50);

  @override
  void onRoundFinished() => rounds++;
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
    testWidgets('opens from the header with a single one-time offer', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Premium'));
      await settle(tester);

      expect(find.text('Premium'), findsWidgets);
      expect(find.text('No ads, forever'), findsOneWidget);
      expect(find.text('One payment, no subscription'), findsOneWidget);
      expect(find.text('Premium for life'), findsOneWidget);
      expect(find.text('One-time payment'), findsOneWidget);
      expect(find.byKey(const Key('premium_price')), findsOneWidget);

      // The old subscription plans are gone.
      for (final gone in ['Monthly', 'Yearly', 'Lifetime']) {
        expect(find.text(gone), findsNothing);
      }
    });

    // Nothing can be bought yet: both actions only tell the user so. (The
    // messenger shows a snack bar on every Scaffold, including the one below,
    // hence findsWidgets.)
    for (final action in ['Unlock Premium', 'Restore purchases']) {
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

  group('ads', () {
    test('an ad is due from round N on, and only until it was shown', () {
      final pacer = InterstitialPacer(after: 3);
      expect(pacer.onRound(), isFalse);
      expect(pacer.onRound(), isFalse);
      expect(pacer.onRound(), isTrue); // round 3: due
      pacer.markShown();
      // Nothing more in this game, however long it goes on.
      expect([
        for (var i = 0; i < 20; i++) pacer.onRound(),
      ], everyElement(false));
    });

    test('the default is one ad, at round 6', () {
      final pacer = InterstitialPacer();
      final due = [for (var i = 1; i <= 12; i++) pacer.onRound()];
      expect(due.indexOf(true) + 1, 6);
      pacer.markShown();
      expect([
        for (var i = 0; i < 12; i++) pacer.onRound(),
      ], everyElement(false));
    });

    test('an ad that was not ready stays due for the next rounds', () {
      final pacer = InterstitialPacer(after: 2);
      expect(pacer.onRound(), isFalse);
      expect(pacer.onRound(), isTrue); // due, but suppose it was not loaded
      expect(pacer.onRound(), isTrue); // still due next round
      pacer.markShown();
      expect(pacer.onRound(), isFalse);
    });

    test('a new game gets a fresh budget', () {
      final pacer = InterstitialPacer(after: 2);
      pacer.onRound();
      expect(pacer.onRound(), isTrue);
      pacer.markShown();
      expect(pacer.onRound(), isFalse);

      pacer.reset(); // another game starts
      expect(pacer.onRound(), isFalse);
      expect(pacer.onRound(), isTrue); // again after 2 rounds
    });

    test('"ads removed" is saved and restored', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await SettingsController.load();
      expect(first.adsRemoved, isFalse);
      await first.setAdsRemoved(true);
      expect((await SettingsController.load()).adsRemoved, isTrue);
    });

    testWidgets('the home screen shows the banner', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), ads: FakeAdService()),
      );
      expect(find.byKey(const Key('fake_banner')), findsOneWidget);
    });

    testWidgets('every finished round is reported, not skips or type swaps', (
      tester,
    ) async {
      phone(tester);
      final ads = FakeAdService();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), ads: ads),
      );
      await tester.tap(find.text('Truth or Dare'));
      await settle(tester);
      await startGame(tester);
      await loaded(tester);
      expect(ads.rounds, 0);

      await tester.tap(find.text('Change Type'));
      await settle(tester);
      expect(ads.rounds, 0); // changing the card type is not a round

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await settle(tester);
      }
      expect(ads.rounds, 3);
    });

    testWidgets('each game opened reports a start (a fresh ad budget)', (
      tester,
    ) async {
      phone(tester);
      final ads = FakeAdService();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), ads: ads),
      );
      expect(ads.games, 0); // the home screen is not a game

      // First game.
      await tester.tap(find.text('Truth or Dare'));
      await settle(tester);
      await startGame(tester);
      await loaded(tester);
      expect(ads.games, 1);
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(ads.games, 1); // rounds do not start a new game

      // Back to the home screen (past the game and setup screens), then
      // another game.
      Navigator.of(tester.element(find.byType(GameScreen)))
          .popUntil((route) => route.isFirst);
      await settle(tester);
      await tester.tap(find.text('Would You Rather'));
      await settle(tester);
      await startGame(tester);
      await loaded(tester);
      expect(ads.games, 2);
    });
  });

  group('scroll hint', () {
    /// A short screen, so the six cards do not all fit and the grid scrolls.
    void shortPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 1800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    /// Advances the clock in small steps so animations get frames (a single
    /// long pump renders just one).
    Future<void> advance(WidgetTester tester, Duration total) async {
      for (
        var t = Duration.zero;
        t < total;
        t += const Duration(milliseconds: 50)
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;

    testWidgets('is off unless asked for', (tester) async {
      shortPhone(tester);
      await tester.pumpWidget(app());
      await advance(tester, const Duration(seconds: 3));
      expect(offset(tester), 0);
    });

    testWidgets('scrolls down to the last game and back to the top', (
      tester,
    ) async {
      shortPhone(tester);
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), scrollHint: true),
      );
      expect(offset(tester), 0); // waits a moment before starting

      await advance(tester, const Duration(milliseconds: 1500));
      expect(offset(tester), greaterThan(0)); // on its way down

      // It reaches the very end, pauses, then returns.
      await advance(tester, const Duration(milliseconds: 1500));
      final grid = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(grid.position.maxScrollExtent, greaterThan(0));

      await advance(tester, const Duration(seconds: 4));
      expect(offset(tester), 0);
    });

    testWidgets('a touch stops it where it is, for good', (tester) async {
      shortPhone(tester);
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), scrollHint: true),
      );
      await advance(tester, const Duration(milliseconds: 1300));
      expect(offset(tester), greaterThan(0));

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.up();
      final stopped = offset(tester);
      await advance(tester, const Duration(seconds: 5));
      expect(offset(tester), stopped); // no further automatic movement
    });

    testWidgets('still plays if the list only becomes scrollable later', (
      tester,
    ) async {
      // Starts tall: everything fits, so there is nothing to hint at yet...
      phone(tester);
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), scrollHint: true),
      );
      await advance(tester, const Duration(milliseconds: 1200));
      expect(offset(tester), 0);

      // ...then it shrinks (as when the banner loads and takes space).
      tester.view.physicalSize = const Size(1170, 1800);
      // The whole trip may finish within this time, so watch how far it got.
      var furthest = 0.0;
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (offset(tester) > furthest) furthest = offset(tester);
      }
      expect(furthest, greaterThan(0));
    });

    testWidgets('does nothing when every game already fits', (tester) async {
      phone(tester); // tall enough for all six cards
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), scrollHint: true),
      );
      await advance(tester, const Duration(seconds: 5));
      expect(offset(tester), 0);
    });
  });
}
