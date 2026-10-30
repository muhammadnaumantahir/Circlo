import 'package:circlo/core/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('premium page header shows title, subtitle and eyebrow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: PremiumPageHeader(
              eyebrow: 'YOUR SPACE',
              title: 'Your circles',
              subtitle: 'The people and places that matter, together.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('YOUR SPACE'), findsOneWidget);
    expect(find.text('Your circles'), findsOneWidget);
    expect(find.text('The people and places that matter, together.'), findsOneWidget);
  });

  testWidgets('premium glass card invokes its action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PremiumGlassCard(
              onTap: () => tapped = true,
              child: const Text('Open details'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    expect(tapped, isTrue);
  });

  testWidgets('premium profile hero displays account identity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: PremiumProfileHero(
              title: 'Nauman',
              subtitle: 'nauman@example.com',
              initial: 'N',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nauman'), findsOneWidget);
    expect(find.text('nauman@example.com'), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
  });

  test('premium palette uses the FinMate / Stockly brand colours', () {
    expect(CircloPalette.brand, const Color(0xFF2563EB));
    expect(CircloPalette.mint, const Color(0xFF17C7A1));
    expect(CircloPalette.violet, const Color(0xFF8B7CFF));
  });
}
