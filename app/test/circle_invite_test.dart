import 'package:circlo/features/circles/circles_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('join screen prefills and formats a code from an invite link', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: JoinCircleScreen(initialCode: 'abcde-fghjk'),
        ),
      ),
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, 'ABCDE-FGHJK');
    expect(find.text('Ask the circle owner for the join code and enter it below.'), findsOneWidget);
  });

  testWidgets('join screen keeps manual entry available without an invite code', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: JoinCircleScreen()),
      ),
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, isEmpty);
    expect(find.text('Join circle'), findsOneWidget);
  });
}
