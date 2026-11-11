import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_games/main.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('home lists all game modes', (tester) async {
    phone(tester);
    await tester.pumpWidget(const PartyGamesApp());
    for (final title in [
      'Truth or Dare',
      'Most Likely To',
      'Never Have I Ever',
      'Would You Rather',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('setup -> game shows player turns', (tester) async {
    phone(tester);
    await tester.pumpWidget(const PartyGamesApp());
    await tester.tap(find.text('Would You Rather'));
    await tester.pumpAndSettle();

    // Setup screen: players stepper and categories.
    expect(find.byKey(const Key('playersCount')), findsOneWidget);
    for (final label in ['All', 'Friends', 'Party', 'Funny']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.byTooltip('−'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Funny'));
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    expect(find.text('Player 1 of 3'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Player 2 of 3'), findsOneWidget);
  });

  testWidgets('truth or dare can change type', (tester) async {
    phone(tester);
    await tester.pumpWidget(const PartyGamesApp());
    await tester.tap(find.text('Truth or Dare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    final wasTruth = find.text('Truth').evaluate().isNotEmpty;
    await tester.tap(find.text('Change Type'));
    await tester.pumpAndSettle();
    expect(find.text(wasTruth ? 'Dare' : 'Truth'), findsOneWidget);
    // Changing type does not advance the turn.
    expect(find.text('Player 1 of 4'), findsOneWidget);
  });
}
