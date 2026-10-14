import 'package:circlo/features/circles/circle_models.dart';
import 'package:circlo/features/places/place_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('JoinFailure messages do not reveal whether a code exists', () {
    expect(const JoinFailure(JoinFailureKind.invalid).message, contains('not valid or has expired'));
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
  });
}
