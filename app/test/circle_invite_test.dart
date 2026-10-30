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

  testWidgets('join screen formats codes while typing and accepts the supported format', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: JoinCircleScreen())),
    );
    await tester.enterText(find.byType(TextFormField), 'hw6kqb96qz');
    await tester.pump();
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, 'HW6KQ-B96QZ');
    expect(field.validator?.call('HW6KQ-B96QZ'), isNull);
  });

  testWidgets('wide join screen uses the branded two-column layout', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: JoinCircleScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('You’re one step away.'), findsOneWidget);
    expect(find.text('Enter invite code'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
