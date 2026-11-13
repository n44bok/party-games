// Takes the App Store / Google Play screenshots from the real app.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart -d <device>
//
// The screenshots show the app only (no status bar), in English.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:party_games/data/settings.dart';
import 'package:party_games/main.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 6),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await binding.takeScreenshot(name);
  }

  Future<void> open(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pump();
    await tester.tap(find.text(title));
    await settle(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await settle(tester);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Start Game'));
    await tester.pump();
    await tester.tap(find.text('Start Game'));
    await settle(tester);
  }

  testWidgets('store screenshots', (tester) async {
    final settings = await SettingsController.load();
    await settings.setLocale(const Locale('en'));

    // A fresh app on the home screen: much more robust than walking back
    // through dialogs and screens.
    Future<void> home() async {
      await tester.pumpWidget(
        PartyGamesApp(key: UniqueKey(), settings: settings),
      );
      await settle(tester);
    }

    await home();
    await shot(tester, '01_home');

    // Spy: setup with names, then a role.
    await open(tester, 'Spy');
    final fields = find.byType(TextField);
    for (var i = 0; i < 3 && i < fields.evaluate().length; i++) {
      await tester.enterText(fields.at(i), ['Anna', 'Max', 'Sofia'][i]);
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await shot(tester, '02_spy_setup');
    await start(tester);
    await shot(tester, '03_spy_pass');
    await tester.tap(find.text('Show my role'));
    await shot(tester, '04_spy_role');

    await home();
    await open(tester, 'Mafia');
    await shot(tester, '05_mafia_setup');

    await home();
    await open(tester, 'Song Backwards');
    await shot(tester, '06_song_setup');

    await home();
    await open(tester, 'Truth or Dare');
    await start(tester);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      if (find.text('Next').evaluate().isNotEmpty) break;
    }
    await shot(tester, '07_truth_or_dare');

    await home();
    await open(tester, 'Charades');
    await start(tester);
    await shot(tester, '08_charades');

    await home();
    await tester.tap(find.byIcon(Icons.workspace_premium));
    await settle(tester);
    await shot(tester, '09_premium');
  });
}
