import 'package:circlo/features/circles/activity.dart';
import 'package:circlo/features/circles/circle_models.dart';
import 'package:circlo/features/circles/circles_screens.dart';
import 'package:circlo/features/profile/profile_models.dart';
import 'package:circlo/providers.dart';
import 'package:circlo/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Override> overridesFor(List<Circle> circles) => [
        currentUidProvider.overrideWith((ref) => circles.isEmpty ? null : 'u1'),
        profileProvider.overrideWith((ref) => Stream<UserProfile?>.value(null)),
        myCirclesProvider.overrideWith((ref) => Stream<List<Circle>>.value(circles)),
        myJoinRequestsProvider.overrideWith((ref) => Stream<List<JoinRequest>>.value(const [])),
        notificationFeedProvider.overrideWith(
          (ref) => const AsyncValue<List<FeedItem>>.data(<FeedItem>[]),
        ),
      ];

  testWidgets('first-time onboarding offers create/join instead of retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(const []),
        child: const MaterialApp(home: CirclesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your people, in sync.'), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('Join with an invite code'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('main navigation hides map, places and history until a circle exists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(const []),
        child: const MaterialApp(
          home: HomeShell(location: '/circles', child: Scaffold(body: Text('child'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Circles'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Map'), findsNothing);
    expect(find.text('Places'), findsNothing);
    expect(find.text('History'), findsNothing);
  });

  testWidgets('main navigation reveals circle features after membership exists', (tester) async {
    const circle = Circle(
      id: 'circle1',
      name: 'Family',
      ownerUid: 'u1',
      joinCode: 'ABCDEFGHJK',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(const [circle]),
        child: const MaterialApp(
          home: HomeShell(location: '/map', child: Scaffold(body: Text('child'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Circles'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
