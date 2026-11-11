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
}
