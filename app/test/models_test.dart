import 'package:circlo/features/circles/circle_models.dart';
import 'package:circlo/features/location/location_models.dart';
import 'package:circlo/features/places/place_models.dart';
import 'package:circlo/features/profile/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemberLocation.tryFromMap', () {
    test('accepts valid coordinates and defaults missing accuracy', () {
      final location = MemberLocation.tryFromMap('u1', {'lat': 31.52, 'lng': 74.35});
      expect(location, isNotNull);
      expect(location!.lat, 31.52);
      expect(location.lng, 74.35);
      expect(location.accuracy, 0);
    });

    test('rejects missing, non-finite, and out-of-range coordinates', () {
      expect(MemberLocation.tryFromMap('u1', {'lat': 31.52}), isNull);
      expect(MemberLocation.tryFromMap('u1', {'lat': 91, 'lng': 0}), isNull);
      expect(MemberLocation.tryFromMap('u1', {'lat': 0, 'lng': 181}), isNull);
      expect(MemberLocation.tryFromMap('u1', {'lat': double.nan, 'lng': 0}), isNull);
      expect(MemberLocation.tryFromMap('u1', {'lat': 0, 'lng': 0, 'accuracy': -1}), isNull);
      expect(MemberLocation.tryFromMap('u1', {'lat': 0, 'lng': 0, 'accuracy': 'unknown'}), isNull);
      expect(MemberLocation.tryFromMap('u1', {'lat': 0, 'lng': 0, 'accuracy': double.nan}), isNull);
    });
  });

  group('UserProfile.fromMap place suggestions consent', () {
    test('defaults suggestions off and reads an explicit opt-in', () {
      final defaults = UserProfile.fromMap('u1', {
        'displayName': 'Sam',
        'birthYear': 1990,
      });
      expect(defaults.placeSuggestionsEnabled, isFalse);

      final optedIn = UserProfile.fromMap('u1', {
        'displayName': 'Sam',
        'birthYear': 1990,
        'keepHistory': true,
        'placeSuggestionsEnabled': true,
      });
      expect(optedIn.placeSuggestionsEnabled, isTrue);
    });

    test('does not allow suggestions preference to imply private history consent', () {
      final invalidState = UserProfile.fromMap('u1', {
        'displayName': 'Sam',
        'birthYear': 1990,
        'placeSuggestionsEnabled': true,
      });
      expect(invalidState.keepHistory, isFalse);
      expect(invalidState.placeSuggestionsEnabled, isTrue);
      // Provider gates reads on both preferences; Firestore Rules reject this combination.
    });
  });

  group('MyMembership.fromMap', () {
    test('reads sharing switches and a valid pause timestamp', () {
      final until = DateTime(2026, 10, 30, 12);
      final membership = MyMembership.fromMap('c1', {
        'sharesLocation': true,
        'paused': true,
        'historyShared': true,
        'pausedUntil': Timestamp.fromDate(until),
      });
      expect(membership.circleId, 'c1');
      expect(membership.sharesLocation, isTrue);
      expect(membership.paused, isTrue);
      expect(membership.historyShared, isTrue);
      expect(membership.pausedUntil, until);
      expect(membership.isActive, isFalse);
    });

    test('ignores malformed optional pause timestamps instead of throwing', () {
      final membership = MyMembership.fromMap('c1', {
        'sharesLocation': true,
        'paused': false,
        'pausedUntil': 'not-a-timestamp',
      });
      expect(membership.pausedUntil, isNull);
      expect(membership.isActive, isTrue);
    });
  });

  group('isValidLocationSample', () {
    test('accepts valid coordinates and accuracy', () {
      expect(isValidLocationSample(lat: 31.52, lng: 74.35, accuracy: 8), isTrue);
      expect(isValidLocationSample(lat: -90, lng: 180, accuracy: 0), isTrue);
    });

    test('rejects invalid coordinates and accuracy before publishing', () {
      expect(isValidLocationSample(lat: 91, lng: 0, accuracy: 5), isFalse);
      expect(isValidLocationSample(lat: 0, lng: -181, accuracy: 5), isFalse);
      expect(isValidLocationSample(lat: double.nan, lng: 0, accuracy: 5), isFalse);
      expect(isValidLocationSample(lat: 0, lng: 0, accuracy: double.infinity), isFalse);
      expect(isValidLocationSample(lat: 0, lng: 0, accuracy: -1), isFalse);
    });
  });

  group('PlaceSubscription.tryFromMap', () {
    test('accepts valid and older subscription documents', () {
      final subscription = PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'arrive': true,
        'leave': false,
        'memberUids': ['u1', 'u2'],
      });
      expect(subscription, isNotNull);
      expect(subscription!.allMembers, isTrue);
      expect(subscription.paused, isFalse);
      expect(subscription.memberUids, ['u1', 'u2']);
    });

    test('rejects malformed IDs and member lists', () {
      expect(PlaceSubscription.tryFromMap('c1', {'placeId': 12}), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {'placeId': ' '}), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'memberUids': 'not-a-list',
      }), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'memberUids': ['u1', 42],
      }), isNull);
      // A malformed value must not silently enable alerts for every circle member.
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'allMembers': 'false',
      }), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'allMembers': 42,
      }), isNull);
      // A malformed pause flag must not silently resume a subscription.
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'paused': 'true',
      }), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'arrive': 'true',
      }), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'leave': 1,
      }), isNull);
    });
  });

  group('Place.tryFromMap', () {
    test('accepts valid saved place coordinates and radius', () {
      final place = Place.tryFromMap('c1', 'p1', {
        'name': 'Home',
        'lat': 31.52,
        'lng': 74.35,
        'radiusM': 150,
      });
      expect(place, isNotNull);
      expect(place!.name, 'Home');
      expect(place.lat, 31.52);
      expect(place.lng, 74.35);
      expect(place.radiusM, 150);
    });

    test('rejects a non-string name and safely defaults malformed optional creator', () {
      expect(Place.tryFromMap('c1', 'p1', {
        'name': 42,
        'lat': 31.52,
        'lng': 74.35,
        'radiusM': 150,
      }), isNull);

      final place = Place.tryFromMap('c1', 'p1', {
        'name': 'Home',
        'lat': 31.52,
        'lng': 74.35,
        'radiusM': 150,
        'createdBy': 42,
      });
      expect(place, isNotNull);
      expect(place!.createdBy, '');
    });

    test('rejects malformed coordinates and out-of-policy radii', () {
      expect(Place.tryFromMap('c1', 'p1', {'name': 'Home', 'lat': 91, 'lng': 0, 'radiusM': 150}), isNull);
      expect(Place.tryFromMap('c1', 'p1', {'name': 'Home', 'lat': 0, 'lng': double.nan, 'radiusM': 150}), isNull);
      expect(Place.tryFromMap('c1', 'p1', {'name': 'Home', 'lat': 0, 'lng': 0, 'radiusM': double.infinity}), isNull);
      expect(Place.tryFromMap('c1', 'p1', {'name': 'Home', 'lat': 0, 'lng': 0, 'radiusM': 99}), isNull);
      expect(Place.tryFromMap('c1', 'p1', {'name': ' ', 'lat': 0, 'lng': 0, 'radiusM': 150}), isNull);
    });
  });

  test('Circle.fromMap reads approval flag with safe defaults', () {
    final c = Circle.fromMap('c1', {'name': 'Family', 'ownerUid': 'a', 'joinCode': 'ABCDEFGHJK', 'requiresApproval': true});
    expect(c.requiresApproval, isTrue);
    expect(Circle.fromMap('c2', {'name': 'X'}).requiresApproval, isFalse);
  });

  test('Member.fromMap reads sharing flags and defaults them to off', () {
    final m = Member.fromMap('u', {'displayName': 'Bob', 'role': 'member'});
    expect(m.sharesLocation, isFalse);
    expect(m.paused, isFalse);
    expect(m.historyShared, isFalse);
    expect(Member.fromMap('u', {'role': 'owner'}).isOwner, isTrue);
  });

  test('JoinRequest.fromMap marks approved requests', () {
    final r = JoinRequest.fromMap('c1', {'uid': 'u', 'displayName': 'Bob', 'joinCode': 'ABCDEFGHJK', 'status': 'approved'});
    expect(r.approved, isTrue);
    expect(JoinRequest.fromMap('c1', {'status': 'pending'}).approved, isFalse);
  });

  test('circle and member models safely default malformed optional string fields', () {
    final circle = Circle.fromMap('c1', {
      'name': 42,
      'ownerUid': false,
      'joinCode': ['bad'],
    });
    expect(circle.name, '');
    expect(circle.ownerUid, '');
    expect(circle.joinCode, '');

    final member = Member.fromMap('u1', {
      'displayName': 42,
      'role': false,
      'sharesLocation': true,
    });
    expect(member.displayName, 'Member');
    expect(member.role, 'member');
    expect(member.sharesLocation, isTrue);
  });

  test('join request safely ignores malformed optional field types', () {
    final request = JoinRequest.fromMap('c1', {
      'uid': 42,
      'displayName': false,
      'joinCode': ['bad'],
      'status': 'approved',
      'createdAt': 'not-a-timestamp',
    });
    expect(request.uid, '');
    expect(request.displayName, 'Someone');
    expect(request.joinCode, '');
    expect(request.approved, isTrue);
    expect(request.createdAt, isNull);
  });

  test('JoinFailure messages do not reveal whether a code exists', () {
    expect(const JoinFailure(JoinFailureKind.invalid).message, contains('not valid or has expired'));
  });

  group('ArrivalPlan.tryFromMap', () {
    test('parses pending and late-arrival plans', () {
      final expected = DateTime(2026, 10, 29, 15);
      final pending = ArrivalPlan.tryFromMap('c1', 'u1', {
        'memberUid': 'u1',
        'placeId': 'p1',
        'expectedAt': Timestamp.fromDate(expected),
        'createdAt': Timestamp.fromDate(expected.subtract(const Duration(hours: 1))),
        'status': 'pending',
      });
      expect(pending, isNotNull);
      expect(pending!.isPending, isTrue);
      expect(pending.arrivedLate, isFalse);

      final late = ArrivalPlan.tryFromMap('c1', 'u1', {
        'memberUid': 'u1',
        'placeId': 'p1',
        'expectedAt': Timestamp.fromDate(expected),
        'createdAt': Timestamp.fromDate(expected.subtract(const Duration(hours: 1))),
        'status': 'arrived',
        'arrivedAt': Timestamp.fromDate(expected.add(const Duration(minutes: 10))),
      });
      expect(late, isNotNull);
      expect(late!.arrivedLate, isTrue);
    });

    test('rejects malformed statuses, timestamps, and owner fields', () {
      final base = {
        'memberUid': 'u1',
        'placeId': 'p1',
        'expectedAt': Timestamp.fromDate(DateTime(2026, 10, 29, 15)),
        'status': 'pending',
      };
      expect(ArrivalPlan.tryFromMap('c1', 'u1', {...base, 'status': 'missed'}), isNull);
      expect(ArrivalPlan.tryFromMap('c1', 'u1', {...base, 'memberUid': ''}), isNull);
      expect(ArrivalPlan.tryFromMap('c1', 'not-u1', base), isNull);
      expect(ArrivalPlan.tryFromMap('c1', 'u1', {...base, 'expectedAt': 'tomorrow'}), isNull);
    });
  });

  group('ArrivalPlan.tryFromMap', () {
    test('parses pending and late-arrival plans', () {
      final expected = DateTime(2026, 10, 29, 15);
      final pending = ArrivalPlan.tryFromMap('c1', 'u1', {
        'memberUid': 'u1',
        'placeId': 'p1',
        'expectedAt': Timestamp.fromDate(expected),
        'createdAt': Timestamp.fromDate(expected.subtract(const Duration(hours: 1))),
        'status': 'pending',
      });
      expect(pending, isNotNull);
      expect(pending!.isPending, isTrue);
      expect(pending.arrivedLate, isFalse);

      final late = ArrivalPlan.tryFromMap('c1', 'u1', {
        'memberUid': 'u1',
        'placeId': 'p1',
        'expectedAt': Timestamp.fromDate(expected),
        'createdAt': Timestamp.fromDate(expected.subtract(const Duration(hours: 1))),
        'status': 'arrived',
        'arrivedAt': Timestamp.fromDate(expected.add(const Duration(minutes: 10))),
      });
      expect(late, isNotNull);
      expect(late!.arrivedLate, isTrue);
    });

    test('rejects malformed statuses, timestamps, and owner fields', () {
      final base = {
        'memberUid': 'u1',
        'placeId': 'p1',
        'expectedAt': Timestamp.fromDate(DateTime(2026, 10, 29, 15)),
        'status': 'pending',
      };
      expect(ArrivalPlan.tryFromMap('c1', 'u1', {...base, 'status': 'missed'}), isNull);
      expect(ArrivalPlan.tryFromMap('c1', 'u1', {...base, 'memberUid': ''}), isNull);
      expect(ArrivalPlan.tryFromMap('c1', 'u1', {...base, 'expectedAt': 'tomorrow'}), isNull);
      expect(ArrivalPlan.tryFromMap('c1', 'u1', {
        ...base, 'status': 'arrived',
      }), isNull);
    });
  });

  group('PlaceEvent.tryFromMap', () {
    test('accepts valid arrival and departure events', () {
      final arrival = PlaceEvent.tryFromMap('c1', 'e1', {
        'placeId': 'p1',
        'placeName': 'Home',
        'memberUid': 'u1',
        'memberName': 'Alex',
        'type': 'arrive',
        'visitId': 'visit-1',
      });
      expect(arrival, isNotNull);
      expect(arrival!.isArrival, isTrue);
      expect(arrival.occurredAt, isNull);
      final departure = PlaceEvent.tryFromMap('c1', 'e2', {
        'placeId': 'p1',
        'placeName': 'Home',
        'memberUid': 'u1',
        'memberName': 'Alex',
        'type': 'leave',
        'visitId': 'visit-1',
      });
      expect(departure, isNotNull);
      expect(departure!.isArrival, isFalse);
    });

    test('rejects malformed required fields, event types, and timestamps', () {
      final valid = <String, dynamic>{
        'placeId': 'p1',
        'placeName': 'Home',
        'memberUid': 'u1',
        'memberName': 'Alex',
        'type': 'arrive',
        'visitId': 'visit-1',
      };
      expect(PlaceEvent.tryFromMap('c1', 'e1', {...valid, 'type': 'unknown'}), isNull);
      expect(PlaceEvent.tryFromMap('c1', 'e1', {...valid, 'placeId': 9}), isNull);
      expect(PlaceEvent.tryFromMap('c1', 'e1', {...valid, 'memberUid': ''}), isNull);
      expect(PlaceEvent.tryFromMap('c1', 'e1', {...valid, 'occurredAt': 'yesterday'}), isNull);
    });
  });

  group('PlaceSubscription.tryFromMap', () {
    test('rejects malformed subscription documents without throwing', () {
      expect(PlaceSubscription.tryFromMap('c1', {'placeId': 7}), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'memberUids': 'not-a-list',
      }), isNull);
      expect(PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'memberUids': ['valid', 42],
      }), isNull);
    });

    test('accepts a valid subscription document', () {
      final subscription = PlaceSubscription.tryFromMap('c1', {
        'placeId': 'p1',
        'arrive': true,
        'memberUids': ['u1'],
      });
      expect(subscription, isNotNull);
      expect(subscription!.placeId, 'p1');
      expect(subscription.arrive, isTrue);
      expect(subscription.memberUids, ['u1']);
    });
  });

  group('PlaceSubscription.wants', () {
    const all = PlaceSubscription(circleId: 'c', placeId: 'p', arrive: true, leave: false, allMembers: true, memberUids: []);
    const some = PlaceSubscription(circleId: 'c', placeId: 'p', arrive: true, leave: true, allMembers: false, memberUids: ['bob']);
    test('filters by type', () {
      expect(all.wants('arrive', 'x'), isTrue);
      expect(all.wants('leave', 'x'), isFalse);
    });
    test('filters by selected members', () {
      expect(some.wants('arrive', 'bob'), isTrue);
      expect(some.wants('arrive', 'eve'), isFalse);
    });
    test('pause suppresses events without changing saved alert choices', () {
      const paused = PlaceSubscription(
        circleId: 'c',
        placeId: 'p',
        arrive: true,
        leave: false,
        allMembers: false,
        memberUids: ['bob'],
        paused: true,
      );
      expect(paused.enabled, isFalse);
      expect(paused.wants('arrive', 'bob'), isFalse);
      expect(paused.arrive, isTrue);
      expect(paused.leave, isFalse);
      expect(paused.allMembers, isFalse);
      expect(paused.memberUids, ['bob']);
    });
    test('legacy subscription documents default to unpaused', () {
      final legacy = PlaceSubscription.fromMap('c', {
        'placeId': 'p',
        'arrive': true,
        'leave': false,
      });
      expect(legacy.paused, isFalse);
      final saved = PlaceSubscription.fromMap('c', {
        'placeId': 'p',
        'arrive': true,
        'leave': false,
        'paused': true,
      });
      expect(saved.paused, isTrue);
      expect(saved.enabled, isFalse);
    });
  });
}
