import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:party_games/ads/ad_service.dart';
import 'package:party_games/data/content_repository.dart';
import 'package:party_games/data/settings.dart';
import 'package:party_games/main.dart';
import 'package:party_games/models/game_mode.dart';
import 'package:party_games/screens/game_screen.dart';
import 'package:party_games/sound/sound_service.dart';
import 'package:party_games/screens/home_screen.dart';
import 'package:party_games/screens/setup_screen.dart';
import 'package:party_games/screens/spy_game_screen.dart';
import 'package:party_games/spy/spy_round.dart';
import 'package:party_games/widgets/glass_pill.dart';

import 'dart:math' show Random;

import 'package:party_games/widgets/category_chips.dart';

/// In-memory content: no asset I/O, so tests are fast and deterministic.
class FakeRepository extends ContentRepository {
  static const words = {
    'places': ['Airport', 'Beach', 'School'],
    'food': ['Pizza', 'Sushi', 'Soup'],
    'animals': ['Cat', 'Dog', 'Fox'],
    'jobs': ['Pilot', 'Chef', 'Doctor'],
    'sports': ['Tennis', 'Golf', 'Judo'],
    'countries': ['Spain', 'Japan', 'Peru'],
    'transport': ['Tram', 'Boat', 'Taxi'],
    'objects': ['Lamp', 'Key', 'Pen'],
    'clothes': ['Hat', 'Scarf', 'Belt'],
    'nature': ['Lake', 'Cave', 'Snow'],
  };

  /// The default category's words.
  static const places = ['Airport', 'Beach', 'School'];

  @override
  Future<Map<String, List<String>>> loadSpyWords(String lang) async => words;

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
  int prepares = 0;
  int startAds = 0;

  @override
  void prepareInterstitial() => prepares++;

  @override
  void showStartInterstitial() => startAds++;

  @override
  void onGameStarted() => games++;

  @override
  Widget buildBanner() => const SizedBox(key: Key('fake_banner'), height: 50);

  @override
  void onRoundFinished() => rounds++;
}

/// Counts the sounds that would have been played.
class FakeSoundService implements SoundService {
  int warnings = 0;
  int timeUps = 0;

  @override
  void playWarning() => warnings++;

  @override
  void playTimeUp() => timeUps++;
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

/// A window tall enough for the whole Spy setup page, so no scrolling (which
/// can leave a button under the transparent app bar) is needed.
void spyPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 5400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Opens a game from the home grid. With seven cards the last ones are below
/// the fold in a phone-sized window, so scroll to the card first.
Future<void> openGame(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.pump();
  await tester.tap(find.text(title));
}

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

/// Starts a Spy round with a 5 minute timer and plays through the role
/// reveal, ending on the discussion screen.
Future<void> toDiscussion(
  WidgetTester tester,
  SettingsController settings, {
  SoundService sounds = const NoSoundService(),
}) async {
  spyPhone(tester);
  await tester.pumpWidget(
    PartyGamesApp(
      repository: FakeRepository(),
      settings: settings,
      sounds: sounds,
    ),
  );
  await openGame(tester, 'Spy');
  await settle(tester);
  final fiveMinutes = find.descendant(
    of: find.byKey(const Key('timerPills')),
    matching: find.text('5 min'),
  );
  await tester.ensureVisible(fiveMinutes);
  await tester.pump();
  await tester.tap(fiveMinutes);
  await tester.pump();
  await startGame(tester);
  await settle(tester);
  await settle(tester);
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.text('Show my role'));
    await settle(tester);
    await tester.tap(find.text(i == 2 ? 'Hide and start' : 'Hide and pass on'));
    await settle(tester);
  }
  expect(find.text('5:00'), findsOneWidget);
}

void main() {
  testWidgets('home lists all game modes', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    for (final title in [
      'Spy',
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
      await openGame(tester, title);
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
    await openGame(tester, 'Would You Rather');
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
    await openGame(tester, 'Most Likely To');
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
    await openGame(tester, 'Most Likely To');
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
    await openGame(tester, 'Most Likely To');
    await settle(tester);

    await tester.tap(find.byTooltip('−'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('truth or dare can change type', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await openGame(tester, 'Truth or Dare');
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
    await openGame(tester, 'Truth or Dare');
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
    expect(find.byTooltip('Rules'), findsNWidgets(7));

    // The second card is Truth or Dare (Spy is first); the help button must
    // not open the game.
    await tester.tap(find.byTooltip('Rules').at(1));
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
      await tester.tap(find.byKey(const Key('hapticsSwitch')));
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
      await openGame(tester, 'Truth or Dare');
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
      await openGame(tester, 'Truth or Dare');
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
      await openGame(tester, 'Truth or Dare');
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
      await openGame(tester, 'Would You Rather');
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

    /// Tall enough for all seven cards.
    void tallPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 3600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('still plays if the list only becomes scrollable later', (
      tester,
    ) async {
      // Starts tall: everything fits, so there is nothing to hint at yet...
      tallPhone(tester);
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
      tallPhone(tester);
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), scrollHint: true),
      );
      await advance(tester, const Duration(seconds: 5));
      expect(offset(tester), 0);
    });
  });

  group('spy rules', () {
    test('spies are a minority: 1 up to 4 players, 2 from 5', () {
      expect(SpyRound.maxSpiesFor(3), 1);
      expect(SpyRound.maxSpiesFor(4), 1);
      expect(SpyRound.maxSpiesFor(5), 2);
      expect(SpyRound.maxSpiesFor(6), 2);
      expect(SpyRound.maxSpiesFor(12), 5);
    });

    test('a round has the requested number of distinct spies', () {
      for (var seed = 0; seed < 50; seed++) {
        final round = SpyRound.start(
          players: 6,
          spies: 2,
          words: FakeRepository.places,
          random: Random(seed),
        );
        expect(round.spyIndexes.length, 2);
        expect(round.spyIndexes.every((i) => i >= 0 && i < 6), isTrue);
        expect(FakeRepository.places, contains(round.word));
        expect(round.firstAsker, inInclusiveRange(0, 5));
        expect(
          [for (var i = 0; i < 6; i++) round.isSpy(i)].where((x) => x).length,
          2,
        );
      }
    });

    test('the same seed gives the same round', () {
      SpyRound make() => SpyRound.start(
        players: 5,
        spies: 1,
        words: FakeRepository.places,
        random: Random(7),
      );
      final a = make();
      final b = make();
      expect(a.word, b.word);
      expect(a.spyIndexes, b.spyIndexes);
      expect(a.firstAsker, b.firstAsker);
    });

    test('everyone gets a turn at being the spy over many rounds', () {
      final seen = <int>{};
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        seen.addAll(
          SpyRound.start(
            players: 4,
            spies: 1,
            words: FakeRepository.places,
            random: random,
          ).spyIndexes,
        );
      }
      expect(seen, {0, 1, 2, 3});
    });
  });

  group('spy game', () {
    Future<void> openSpy(WidgetTester tester) async {
      spyPhone(tester);
      await tester.pumpWidget(app());
      await openGame(tester, 'Spy');
      await settle(tester);
    }

    Finder pills(String key, String label) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.widgetWithText(GlassPill, label),
    );

    /// The options are below the fold of a phone-sized window: scroll first.
    Future<void> tapPill(WidgetTester tester, Finder pill) async {
      await tester.ensureVisible(pill);
      await tester.pump();
      await tester.tap(pill);
      await tester.pump();
    }

    bool enabled(WidgetTester tester, Finder pill) =>
        tester.widget<GlassPill>(pill).enabled;
    bool selected(WidgetTester tester, Finder pill) =>
        tester.widget<GlassPill>(pill).selected;

    String textOf(WidgetTester tester, String key) {
      final keyed = find.byKey(Key(key));
      final widget = tester.widget(keyed);
      if (widget is Text) return widget.data!; // the key is on the Text itself
      return tester
          .widget<Text>(find.descendant(of: keyed, matching: find.byType(Text)))
          .data!;
    }

    testWidgets('is the first game on the home screen', (tester) async {
      expect(GameMode.values.first, GameMode.spy);

      phone(tester);
      await tester.pumpWidget(app());
      // Top row, left column: above the second row and left of the next card.
      final spy = tester.getTopLeft(find.text('Spy'));
      expect(
        spy.dx,
        lessThan(tester.getTopLeft(find.text('Truth or Dare')).dx),
      );
      expect(
        spy.dy,
        lessThan(tester.getTopLeft(find.text('Most Likely To')).dy),
      );
    });

    testWidgets('its rules are explained in the help popover', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Rules').first);
      await settle(tester);
      expect(find.textContaining('secret word'), findsOneWidget);
    });

    testWidgets('setup starts at three players, which is also the minimum', (
      tester,
    ) async {
      await openSpy(tester);
      expect(find.byType(TextField), findsNWidgets(3));

      await tester.tap(find.byTooltip('−')); // already at the minimum
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(3));

      await tester.tap(find.byTooltip('+'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('two spies need five players', (tester) async {
      await openSpy(tester);
      // Three players: one spy only.
      expect(enabled(tester, pills('spyCountPills', '2')), isFalse);
      expect(selected(tester, pills('spyCountPills', '1')), isTrue);

      await tester.tap(find.byTooltip('+')); // four: still one spy
      await tester.pump();
      expect(enabled(tester, pills('spyCountPills', '2')), isFalse);

      await tester.tap(find.byTooltip('+')); // five players
      await tester.pump();
      expect(enabled(tester, pills('spyCountPills', '2')), isTrue);
      await tapPill(tester, pills('spyCountPills', '2'));
      expect(selected(tester, pills('spyCountPills', '2')), isTrue);

      // Back to four: two spies are no longer allowed, so it falls back to 1.
      await tester.ensureVisible(find.byTooltip('−')); // we scrolled down
      await tester.pump();
      await tester.tap(find.byTooltip('−'));
      await tester.pump();
      expect(selected(tester, pills('spyCountPills', '1')), isTrue);
      expect(enabled(tester, pills('spyCountPills', '2')), isFalse);
    });

    testWidgets('ten word categories plus your own, Places by default', (
      tester,
    ) async {
      await openSpy(tester);
      for (final label in [
        'Places',
        'Food',
        'Animals',
        'Jobs',
        'Sports',
        'Countries',
        'Transport',
        'Objects',
        'Clothes',
        'Nature',
        'My word',
      ]) {
        expect(pills('spyCategoryPills', label), findsOneWidget);
      }
      expect(selected(tester, pills('spyCategoryPills', 'Places')), isTrue);

      await tapPill(tester, pills('spyCategoryPills', 'Food'));
      expect(selected(tester, pills('spyCategoryPills', 'Food')), isTrue);
      expect(selected(tester, pills('spyCategoryPills', 'Places')), isFalse);
    });

    for (final entry in {
      'Places': 'places',
      'Food': 'food',
      'Animals': 'animals',
      'Jobs': 'jobs',
      'Sports': 'sports',
      'Countries': 'countries',
      'Transport': 'transport',
      'Objects': 'objects',
      'Clothes': 'clothes',
      'Nature': 'nature',
    }.entries) {
      testWidgets('the "${entry.key}" category uses its own words', (
        tester,
      ) async {
        await openSpy(tester);
        await tapPill(tester, pills('spyCategoryPills', entry.key));
        await startGame(tester);
        await settle(tester);
        await settle(tester);

        final expected = FakeRepository.words[entry.value]!;
        final seen = <String>{};
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Show my role'));
          await settle(tester);
          if (find.byKey(const Key('spyWord')).evaluate().isNotEmpty) {
            seen.add(textOf(tester, 'spyWord'));
          }
          await tester.tap(
            find.text(i == 2 ? 'Hide and start' : 'Hide and pass on'),
          );
          await settle(tester);
        }
        expect(seen.length, 1);
        expect(expected, contains(seen.single));
      });
    }

    testWidgets('timer length can be chosen, 8 minutes by default', (
      tester,
    ) async {
      await openSpy(tester);
      for (final label in ['5 min', '8 min', '10 min', '15 min']) {
        expect(pills('timerPills', label), findsOneWidget);
      }
      expect(selected(tester, pills('timerPills', '8 min')), isTrue);
      await tapPill(tester, pills('timerPills', '15 min'));
      expect(selected(tester, pills('timerPills', '15 min')), isTrue);
      expect(selected(tester, pills('timerPills', '8 min')), isFalse);
    });

    testWidgets('a full round: roles, discussion, result, play again', (
      tester,
    ) async {
      await openSpy(tester);
      const names = ['Anna', 'Bohdan', 'Carla'];
      for (var i = 0; i < names.length; i++) {
        await tester.enterText(find.byType(TextField).at(i), names[i]);
      }
      await startGame(tester);
      await settle(tester);
      await settle(tester);

      // Reveal: pass the phone around; each player sees their own role.
      String? spyName;
      final words = <String>{};
      for (var i = 0; i < names.length; i++) {
        expect(textOf(tester, 'spyProgress'), '${i + 1} / 3');
        expect(textOf(tester, 'spyPassName'), names[i]);
        // Nothing secret is on screen before the player asks for it.
        expect(find.byKey(const Key('spyRole')), findsNothing);
        expect(find.byKey(const Key('spyWord')), findsNothing);

        await tester.tap(find.text('Show my role'));
        await settle(tester);
        if (find.byKey(const Key('spyRole')).evaluate().isNotEmpty) {
          expect(spyName, isNull, reason: 'only one spy');
          spyName = names[i];
          expect(find.byKey(const Key('spyWord')), findsNothing);
        } else {
          words.add(textOf(tester, 'spyWord'));
        }
        await tester.tap(
          find.text(
            i == names.length - 1 ? 'Hide and start' : 'Hide and pass on',
          ),
        );
        await settle(tester);
      }
      expect(spyName, isNotNull);
      expect(words.length, 1); // everyone but the spy saw the same word
      expect(FakeRepository.places, contains(words.single));

      // Discussion: the timer runs, can be paused and resumed.
      expect(find.text('8:00'), findsOneWidget);
      expect(find.textContaining('asks the first question'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('7:57'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('7:57'), findsOneWidget); // held while paused
      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('7:55'), findsOneWidget);

      // There is no word list to open: only pause and reveal are offered.
      expect(find.text('Words'), findsNothing);

      // Result: the real spy and the place.
      await tester.tap(find.text('Reveal the spy'));
      await settle(tester);
      expect(textOf(tester, 'spyName'), spyName);
      expect(find.text('The spy was'), findsOneWidget);
      expect(find.byKey(const Key('spyResultWord')), findsOneWidget);
      expect(
        (tester.widget<Text>(find.byKey(const Key('spyResultWord')))).data,
        words.single,
      );

      // Play again: a fresh round with the same players.
      await tester.tap(find.text('Play again'));
      await settle(tester);
      expect(textOf(tester, 'spyProgress'), '1 / 3');
      expect(textOf(tester, 'spyPassName'), 'Anna');
    });

    testWidgets('time runs out: the vote is called and pause goes away', (
      tester,
    ) async {
      await openSpy(tester);
      await tapPill(tester, pills('timerPills', '5 min'));
      await startGame(tester);
      await settle(tester);
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Show my role'));
        await settle(tester);
        await tester.tap(
          find.text(i == 2 ? 'Hide and start' : 'Hide and pass on'),
        );
        await settle(tester);
      }
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('Time is up! Vote for the spy.'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
    });

    testWidgets('Finish goes back to the home screen, not the setup', (
      tester,
    ) async {
      await openSpy(tester);
      await startGame(tester);
      await settle(tester);
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Show my role'));
        await settle(tester);
        await tester.tap(
          find.text(i == 2 ? 'Hide and start' : 'Hide and pass on'),
        );
        await settle(tester);
      }
      await tester.tap(find.text('Reveal the spy'));
      await settle(tester);
      expect(find.byType(SpyGameScreen), findsOneWidget);

      await tester.tap(find.text('Finish'));
      // Two routes are popped at once; let both transitions run out.
      await tester.pumpAndSettle();

      // Neither the game nor its setup screen is left on the stack.
      expect(find.byType(SpyGameScreen), findsNothing);
      expect(find.byType(SetupScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Truth or Dare'), findsOneWidget);
    });

    testWidgets('two spies are both named in the result', (tester) async {
      await openSpy(tester);
      await tester.tap(find.byTooltip('+'));
      await tester.tap(find.byTooltip('+')); // 3 -> 5 players
      await tester.pump();
      await tapPill(tester, pills('spyCountPills', '2'));
      await startGame(tester);
      await settle(tester);
      await settle(tester);

      var spies = 0;
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Show my role'));
        await settle(tester);
        if (find.byKey(const Key('spyRole')).evaluate().isNotEmpty) spies++;
        await tester.tap(
          find.text(i == 4 ? 'Hide and start' : 'Hide and pass on'),
        );
        await settle(tester);
      }
      expect(spies, 2);

      await tester.tap(find.text('Reveal the spy'));
      await settle(tester);
      expect(find.text('The spies were'), findsOneWidget);
      expect(find.byKey(const Key('spyName')), findsNWidgets(2));
    });
  });

  group('spy ads', () {
    Future<FakeAdService> openSpySetup(WidgetTester tester) async {
      spyPhone(tester);
      final ads = FakeAdService();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), ads: ads),
      );
      await openGame(tester, 'Spy');
      await settle(tester);
      return ads;
    }

    Future<void> playThroughRoles(WidgetTester tester, int players) async {
      for (var i = 0; i < players; i++) {
        await tester.tap(find.text('Show my role'));
        await settle(tester);
        await tester.tap(
          find.text(i == players - 1 ? 'Hide and start' : 'Hide and pass on'),
        );
        await settle(tester);
      }
    }

    testWidgets('the ad is loaded in advance, when the setup opens', (
      tester,
    ) async {
      final ads = await openSpySetup(tester);
      expect(ads.prepares, 1);
      expect(ads.startAds, 0); // nothing shown before the game starts
    });

    testWidgets('exactly one ad, when the game starts', (tester) async {
      final ads = await openSpySetup(tester);
      await startGame(tester);
      await settle(tester);
      await settle(tester);
      expect(ads.startAds, 1);

      // Then no more, however the game goes on: roles, discussion, result,
      // and further rounds with "Play again".
      await playThroughRoles(tester, 3);
      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.text('Reveal the spy'));
      await settle(tester);
      await tester.tap(find.text('Play again'));
      await settle(tester);
      await playThroughRoles(tester, 3);
      await tester.tap(find.text('Reveal the spy'));
      await settle(tester);
      expect(ads.startAds, 1);
      expect(ads.rounds, 0); // Spy has no "rounds" that count towards an ad
    });

    testWidgets('leaving to the setup and starting again shows it again', (
      tester,
    ) async {
      final ads = await openSpySetup(tester);
      await startGame(tester);
      await settle(tester);
      await settle(tester);
      expect(ads.startAds, 1);

      // Back to the setup screen (pop only the game), then start again.
      Navigator.of(tester.element(find.byType(SpyGameScreen))).pop();
      await settle(tester);
      await startGame(tester);
      await settle(tester);
      await settle(tester);
      expect(ads.startAds, 2);
    });

    testWidgets('card games do not use the start ad', (tester) async {
      phone(tester);
      final ads = FakeAdService();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), ads: ads),
      );
      await openGame(tester, 'Truth or Dare');
      await settle(tester);
      await startGame(tester);
      await loaded(tester);
      expect(ads.prepares, 0);
      expect(ads.startAds, 0);
    });
  });

  group('time warning', () {
    test('is on by default and is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsController.load();
      expect(settings.timeWarning, isTrue);
      await settings.setTimeWarning(false);
      expect((await SettingsController.load()).timeWarning, isFalse);
    });

    testWidgets('is a Spy option, not a general setting', (tester) async {
      // Not among the general settings...
      phone(tester);
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.text('Time warning'), findsNothing);
      expect(find.byKey(const Key('timeWarningSwitch')), findsNothing);
    });

    testWidgets('it is switched in the Spy setup and remembered', (
      tester,
    ) async {
      spyPhone(tester);
      final settings = SettingsController();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), settings: settings),
      );
      await openGame(tester, 'Spy');
      await settle(tester);

      expect(find.text('Time warning'), findsOneWidget);
      expect(find.text('A signal 20 seconds before the end'), findsOneWidget);
      final warningSwitch = find.byKey(const Key('timeWarningSwitch'));
      expect(tester.widget<Switch>(warningSwitch).value, isTrue);

      await tester.ensureVisible(warningSwitch);
      await tester.pump();
      await tester.tap(warningSwitch);
      await tester.pump();
      expect(tester.widget<Switch>(warningSwitch).value, isFalse);
      expect(settings.timeWarning, isFalse); // remembered for next time
      // Independent of the sound switch.
      expect(settings.sound, isTrue);
    });

    testWidgets('the setup starts from the remembered choice', (tester) async {
      spyPhone(tester);
      await tester.pumpWidget(
        PartyGamesApp(
          repository: FakeRepository(),
          settings: SettingsController(timeWarning: false),
        ),
      );
      await openGame(tester, 'Spy');
      await settle(tester);
      expect(
        tester.widget<Switch>(find.byKey(const Key('timeWarningSwitch'))).value,
        isFalse,
      );
    });

    testWidgets('the players are told to hurry with 20 seconds to go', (
      tester,
    ) async {
      await toDiscussion(tester, SettingsController());

      await tester.pump(const Duration(seconds: 279)); // 0:21 left
      expect(find.text('0:21'), findsOneWidget);
      expect(find.text('Hurry up!'), findsNothing);
      expect(find.text('Time left'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1)); // 0:20 left
      expect(find.text('0:20'), findsOneWidget);
      expect(find.text('Hurry up!'), findsOneWidget);
      expect(find.text('Time left'), findsNothing);

      // It stays until the time is up, then the vote is called instead.
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Hurry up!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('Hurry up!'), findsNothing);
      expect(find.text('Time is up! Vote for the spy.'), findsOneWidget);
    });

    testWidgets('stays quiet when switched off', (tester) async {
      await toDiscussion(tester, SettingsController(timeWarning: false));

      await tester.pump(const Duration(seconds: 285)); // 0:15 left
      expect(find.text('0:15'), findsOneWidget);
      expect(find.text('Hurry up!'), findsNothing);
      expect(find.text('Time left'), findsOneWidget);
    });

    testWidgets('pausing inside the last 20 seconds keeps the warning', (
      tester,
    ) async {
      await toDiscussion(tester, SettingsController());
      await tester.pump(const Duration(seconds: 285)); // 0:15 left
      expect(find.text('Hurry up!'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('0:15'), findsOneWidget); // paused
      expect(find.text('Hurry up!'), findsOneWidget);
    });
  });

  group('my word (one word for this game)', () {
    Finder categoryPill(String label) => find.descendant(
      of: find.byKey(const Key('spyCategoryPills')),
      matching: find.text(label),
    );

    Future<SettingsController> openSetup(WidgetTester tester) async {
      spyPhone(tester);
      final settings = SettingsController();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), settings: settings),
      );
      await openGame(tester, 'Spy');
      await settle(tester);
      return settings;
    }

    testWidgets('a field appears for it, and for nothing else', (tester) async {
      await openSetup(tester);
      expect(find.byKey(const Key('singleWordField')), findsNothing);

      await tester.tap(categoryPill('My word'));
      await tester.pump();
      expect(find.byKey(const Key('singleWordField')), findsOneWidget);
      // No explanatory note under the field.
      expect(find.text('Used only for this game, not saved'), findsNothing);

      await tester.tap(categoryPill('Food'));
      await tester.pump();
      expect(find.byKey(const Key('singleWordField')), findsNothing);
    });

    testWidgets('the game needs the word first', (tester) async {
      await openSetup(tester);
      await tester.tap(categoryPill('My word'));
      await tester.pump();

      await startGame(tester);
      await tester.pump();
      expect(find.text('Type the word for this game first'), findsWidgets);
      expect(find.byType(SpyGameScreen), findsNothing);

      // Only spaces is still nothing.
      await tester.enterText(find.byKey(const Key('singleWordField')), '   ');
      await startGame(tester);
      await tester.pump();
      expect(find.byType(SpyGameScreen), findsNothing);
    });

    testWidgets('everyone but the spy sees exactly that word', (tester) async {
      await openSetup(tester);
      await tester.tap(categoryPill('My word'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('singleWordField')),
        '  Mars   rover ',
      );

      await startGame(tester);
      await settle(tester);
      await settle(tester);
      final seen = <String>{};
      var spies = 0;
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Show my role'));
        await settle(tester);
        if (find.byKey(const Key('spyWord')).evaluate().isNotEmpty) {
          seen.add(
            (tester.widget<Text>(find.byKey(const Key('spyWord')))).data!,
          );
        } else {
          spies++;
        }
        await tester.tap(
          find.text(i == 2 ? 'Hide and start' : 'Hide and pass on'),
        );
        await settle(tester);
      }
      expect(spies, 1);
      expect(seen, {'Mars rover'}); // spaces tidied

      // Not saved: a fresh setup starts with an empty field.
      Navigator.of(tester.element(find.byType(SpyGameScreen)))
          .popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      await openGame(tester, 'Spy');
      await settle(tester);
      await tester.tap(categoryPill('My word'));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('singleWordField')),
      );
      expect(field.controller!.text, isEmpty);
    });

    test('the sound setting is on by default and is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsController.load();
      expect(settings.sound, isTrue);
      await settings.setSound(false);
      expect((await SettingsController.load()).sound, isFalse);
    });

    testWidgets('sound can be switched in the settings screen', (tester) async {
      phone(tester);
      final settings = SettingsController();
      await tester.pumpWidget(
        PartyGamesApp(repository: FakeRepository(), settings: settings),
      );
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      expect(find.text('Sound'), findsOneWidget);

      await tester.tap(find.byKey(const Key('soundSwitch')));
      await settle(tester);
      expect(settings.sound, isFalse);
      // Independent of vibration and of the time warning.
      expect(settings.haptics, isTrue);
      expect(settings.timeWarning, isTrue);
    });

    testWidgets('beeps at 20 seconds, and the buzzer when time is out', (
      tester,
    ) async {
      final sounds = FakeSoundService();
      await toDiscussion(tester, SettingsController(), sounds: sounds);

      await tester.pump(const Duration(seconds: 279)); // 0:21 left
      expect(sounds.warnings, 0);
      await tester.pump(const Duration(seconds: 1)); // 0:20 left
      expect(sounds.warnings, 1);
      expect(sounds.timeUps, 0);

      // Only once, however long the last 20 seconds last.
      await tester.pump(const Duration(seconds: 19));
      expect(sounds.warnings, 1);
      expect(sounds.timeUps, 0);

      await tester.pump(const Duration(seconds: 1)); // time is out
      expect(sounds.warnings, 1);
      expect(sounds.timeUps, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(sounds.timeUps, 1); // the timer has stopped
    });

    testWidgets('no sound at all when sound is switched off', (tester) async {
      final sounds = FakeSoundService();
      await toDiscussion(
        tester,
        SettingsController(sound: false),
        sounds: sounds,
      );
      await tester.pump(const Duration(seconds: 300));
      expect(sounds.warnings, 0);
      expect(sounds.timeUps, 0);
      // The visual signals are separate and still there.
      expect(find.text('Time is up! Vote for the spy.'), findsOneWidget);
    });

    testWidgets('with the warning off only the final buzzer sounds', (
      tester,
    ) async {
      final sounds = FakeSoundService();
      await toDiscussion(
        tester,
        SettingsController(timeWarning: false),
        sounds: sounds,
      );
      await tester.pump(const Duration(seconds: 285)); // inside the last 20 s
      expect(sounds.warnings, 0);
      await tester.pump(const Duration(seconds: 15));
      expect(sounds.warnings, 0);
      expect(sounds.timeUps, 1);
    });

    testWidgets('pausing holds back the sounds too', (tester) async {
      final sounds = FakeSoundService();
      await toDiscussion(tester, SettingsController(), sounds: sounds);
      await tester.pump(const Duration(seconds: 270)); // 0:30 left
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 120));
      expect(sounds.warnings, 0);
      expect(sounds.timeUps, 0);
    });

    testWidgets('switched off in the setup, the game does not warn', (
      tester,
    ) async {
      final sounds = FakeSoundService();
      spyPhone(tester);
      await tester.pumpWidget(
        PartyGamesApp(
          repository: FakeRepository(),
          settings: SettingsController(),
          sounds: sounds,
        ),
      );
      await openGame(tester, 'Spy');
      await settle(tester);
      final warningSwitch = find.byKey(const Key('timeWarningSwitch'));
      await tester.ensureVisible(warningSwitch);
      await tester.pump();
      await tester.tap(warningSwitch);
      await tester.pump();
      final fiveMinutes = find.descendant(
        of: find.byKey(const Key('timerPills')),
        matching: find.text('5 min'),
      );
      await tester.ensureVisible(fiveMinutes);
      await tester.pump();
      await tester.tap(fiveMinutes);
      await tester.pump();
      await startGame(tester);
      await settle(tester);
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Show my role'));
        await settle(tester);
        await tester.tap(
          find.text(i == 2 ? 'Hide and start' : 'Hide and pass on'),
        );
        await settle(tester);
      }

      await tester.pump(const Duration(seconds: 285)); // 0:15 left
      expect(find.text('Hurry up!'), findsNothing);
      expect(sounds.warnings, 0);
      await tester.pump(const Duration(seconds: 15));
      expect(sounds.timeUps, 1); // the end still sounds
    });
  });
}
