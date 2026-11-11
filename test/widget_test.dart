import 'package:flutter_test/flutter_test.dart';
import 'package:party_games/main.dart';

void main() {
  testWidgets('home lists all game modes and opens one', (tester) async {
    await tester.pumpWidget(const PartyGamesApp());
    expect(find.text('Would You Rather'), findsOneWidget);
    expect(find.text('Most Likely To'), findsOneWidget);
    expect(find.text('Truth or Dare'), findsOneWidget);

    await tester.tap(find.text('Would You Rather'));
    await tester.pumpAndSettle();
    expect(find.text('OR'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('OR'), findsOneWidget);
  });

  testWidgets('category chips are shown and switchable', (tester) async {
    await tester.pumpWidget(const PartyGamesApp());
    await tester.tap(find.text('Truth or Dare'));
    await tester.pumpAndSettle();

    for (final label in ['All', 'Friends', 'Party', 'Funny']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Funny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget); // still playable
  });
}
