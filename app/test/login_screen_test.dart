import 'package:circlo/features/auth/auth_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login shows validation errors and does not call Firebase when empty', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('signup exposes Google sign-in and keeps the birth-year requirement', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SignUpScreen())));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Birth year'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
  });
}
