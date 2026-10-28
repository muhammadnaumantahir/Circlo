import 'package:circlo/features/circles/activity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('manual member check-ins', () {
    test('supports the four user-selected statuses', () {
      expect(kCheckInStatuses.keys, [
        'im_okay',
        'arrived_safely',
        'on_my_way',
        'running_late',
      ]);
      expect(kCheckInStatuses['arrived_safely'], 'Arrived safely');
    });

    test('parses a check-in into a self-reported activity message', () {
      final event = ActivityEvent.fromMap('circle-1', 'event-1', {
        'type': 'checked_in',
        'actorUid': 'member-1',
        'actorName': 'Sam',
        'checkInStatus': 'arrived_safely',
        'occurredAt': Timestamp.fromDate(DateTime(2026, 10, 28, 12)),
      });

      expect(event, isNotNull);
      expect(event!.type, ActivityType.checkedIn);
      expect(event.text, 'Sam shared a manual check-in: Arrived safely');
      expect(event.checkInStatus, 'arrived_safely');
    });

    test('keeps unrelated legacy activity parsing and ignores unknown types', () {
      final joined = ActivityEvent.fromMap('circle-1', 'event-2', {
        'type': 'joined',
        'actorUid': 'member-2',
        'actorName': 'Alex',
        'occurredAt': Timestamp.now(),
      });
      expect(joined!.type, ActivityType.joined);
      expect(joined.text, 'Alex joined the circle');
      expect(ActivityEvent.fromMap('circle-1', 'event-3', {
        'type': 'unknown',
        'actorUid': 'x',
        'actorName': 'Someone',
        'occurredAt': Timestamp.now(),
      }), isNull);
    });
  });
}
