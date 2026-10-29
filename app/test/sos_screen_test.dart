import 'package:circlo/features/circles/circle_models.dart';
import 'package:circlo/features/location/location_models.dart';
import 'package:circlo/features/profile/profile_models.dart';
import 'package:circlo/features/sos/sos_screen.dart';
import 'package:circlo/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _circle = Circle(
  id: 'family',
  name: 'Family',
  ownerUid: 'self',
  joinCode: 'ABCDEFG234',
);

const _profile = UserProfile(
  uid: 'self',
  displayName: 'Nauman',
  birthYear: 1990,
);

Widget _app({
  required DateTime? locationUpdatedAt,
  bool sharingActive = true,
  bool paused = false,
  bool membershipKnown = true,
  double locationLat = 31.5204,
  double locationLng = 74.3587,
  double locationAccuracy = 25,
}) {
  final contacts = <SharedContact>[
    const SharedContact(uid: 'self', phone: '+923001111111'),
    const SharedContact(uid: 'removed', phone: '+923002222222'),
    const SharedContact(uid: 'bad-phone', phone: 'not-a-phone'),
    const SharedContact(uid: 'zara', phone: '+923003333333'),
    const SharedContact(uid: 'amina', phone: '+923004444444'),
  ];
  final members = <Member>[
    const Member(uid: 'self', displayName: 'Nauman', role: 'owner'),
    const Member(uid: 'zara', displayName: 'Zara', role: 'member'),
    const Member(uid: 'amina', displayName: 'Amina', role: 'member'),
    const Member(uid: 'bad-phone', displayName: 'Malformed Phone', role: 'member'),
  ];
  final myLocation = MemberLocation(
    uid: 'self',
    lat: locationLat,
    lng: locationLng,
    accuracy: locationAccuracy,
    updatedAt: locationUpdatedAt,
  );

  return ProviderScope(
    overrides: [
      currentUidProvider.overrideWithValue('self'),
      myCirclesProvider.overrideWith((ref) => Stream.value([_circle])),
      profileProvider.overrideWith((ref) => Stream.value(_profile)),
      myMembershipsProvider.overrideWith(
        (ref) => Stream.value(
          membershipKnown
              ? [
                  MyMembership(
                    circleId: 'family',
                    sharesLocation: sharingActive || paused,
                    paused: paused,
                  ),
                ]
              : const <MyMembership>[],
        ),
      ),
      locationsProvider('family').overrideWith(
        (ref) => Stream.value({'self': myLocation}),
      ),
      membersProvider('family').overrideWith((ref) => Stream.value(members)),
      sharedContactsProvider('family').overrideWith((ref) => Stream.value(contacts)),
    ],
    child: const MaterialApp(home: SosScreen()),
  );
}

void main() {
  testWidgets('SOS contact actions only show valid shared contacts in the current Circle', (tester) async {
    await tester.pumpWidget(
      _app(locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contact someone in this Circle'), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Zara'), findsOneWidget);
    expect(find.text('Malformed Phone'), findsNothing);
    expect(find.text('No shared phone numbers yet'), findsNothing);
    expect(find.text('Choose who to share with'), findsOneWidget);
    expect(find.textContaining('Nothing is sent until you choose a recipient'), findsOneWidget);
  });

  testWidgets('stale location is not included in the SOS message preview', (tester) async {
    await tester.pumpWidget(
      _app(locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 20))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No fresh shared location'), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(preview, contains('does not have a fresh shared location'));
    expect(preview, isNot(contains('www.google.com/maps/search/')));
  });

  testWidgets('sharing-off guidance does not tell the user that sharing is already on', (tester) async {
    await tester.pumpWidget(
      _app(
        locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        sharingActive: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location sharing is off for this Circle. No coordinates will be included. Turn it on and wait for a fresh fix to include your location.'), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(preview, isNot(contains('www.google.com/maps/search/')));
  });

  testWidgets('paused sharing omits a fresh location and explains how to resume', (tester) async {
    await tester.pumpWidget(
      _app(
        locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        sharingActive: true,
        paused: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location sharing is paused for this Circle. No coordinates will be included. Resume sharing and wait for a fresh fix to include your location.'), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(preview, isNot(contains('www.google.com/maps/search/')));
  });

  testWidgets('unconfirmed sharing state never includes a fresh location', (tester) async {
    await tester.pumpWidget(
      _app(
        locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        membershipKnown: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sharing status is not yet confirmed for this Circle. No coordinates will be included.'), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(preview, isNot(contains('www.google.com/maps/search/')));
  });

  testWidgets('invalid location coordinates are not included and are explained', (tester) async {
    await tester.pumpWidget(
      _app(
        locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        locationLat: 91,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The last shared location has invalid coordinates or accuracy. No coordinates will be included until a valid location update arrives.'), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(preview, isNot(contains('www.google.com/maps/search/')));
  });

  testWidgets('missing location timestamp is shown as unavailable', (tester) async {
    await tester.pumpWidget(_app(locationUpdatedAt: null));
    await tester.pumpAndSettle();

    expect(find.text('No fresh shared location'), findsOneWidget);
    final preview = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(preview, isNot(contains('www.google.com/maps/search/')));
  });
}
