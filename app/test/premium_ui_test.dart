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

  testWidgets('premium status pill exposes its state and tap action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PremiumStatusPill(
              label: 'Sharing',
              icon: Icons.location_on_rounded,
              color: CircloPalette.success,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sharing'), findsOneWidget);
    await tester.tap(find.text('Sharing'));
    expect(tapped, isTrue);
  });

  testWidgets('premium section groups tiles beneath a heading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: PremiumSection(
              title: 'Privacy & data',
              children: [
                PremiumTile(
                  icon: Icons.history_rounded,
                  title: 'Travel history settings',
                ),
                PremiumTile(
                  icon: Icons.share_location_rounded,
                  title: 'Location sharing',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('PRIVACY & DATA'), findsOneWidget);
    expect(find.text('Travel history settings'), findsOneWidget);
    expect(find.text('Location sharing'), findsOneWidget);
  });

  testWidgets('premium filter chip reports selected state and count', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PremiumFilterChip(
              label: 'Places',
              count: '4',
              icon: Icons.place_rounded,
              selected: false,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Places'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.byType(PremiumFilterChip));
    expect(selected, isTrue);
  });

  test('premium palette uses the FinMate / Stockly brand colours', () {
    expect(CircloPalette.brand, const Color(0xFF2563EB));
    expect(CircloPalette.mint, const Color(0xFF17C7A1));
    expect(CircloPalette.violet, const Color(0xFF8B7CFF));
  });
}
