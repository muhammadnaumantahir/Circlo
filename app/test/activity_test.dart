import 'package:circlo/features/circles/activity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quick emoji notes', () {
    test('uses only the curated one-tap messages', () {
      expect(kQuickNotes['❤️'], 'Love you');
      expect(kQuickNotes['🚗'], 'On the road');
      expect(kQuickNotes.length, 8);
    });

    test('parses a quick note as a message rather than a location check-in', () {
      final event = ActivityEvent.fromMap('circle-1', 'note-1', {
        'type': 'quick_note',
        'actorUid': 'member-1',
        'actorName': 'Sam',
        'quickNoteEmoji': '❤️',
        'quickNoteText': 'Love you',
        'occurredAt': Timestamp.fromDate(DateTime(2026, 10, 29, 12)),
      });

      expect(event, isNotNull);
      expect(event!.type, ActivityType.quickNote);
      expect(event.text, 'Sam sent a quick note: ❤️ Love you');
      expect(event.quickNoteEmoji, '❤️');
      expect(event.quickNoteText, 'Love you');
      expect(event.checkInStatus, isNull);
      expect(event.checkInPlaceName, isNull);
    });
  });

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
        'checkInPlaceId': 'place-1',
        'checkInPlaceName': 'School',
        'occurredAt': Timestamp.fromDate(DateTime(2026, 10, 28, 12)),
      });

      expect(event, isNotNull);
      expect(event!.type, ActivityType.checkedIn);
      expect(event.text, 'Sam shared a manual check-in: Arrived safely · at School');
      expect(event.checkInStatus, 'arrived_safely');
      expect(event.checkInPlaceId, 'place-1');
      expect(event.checkInPlaceName, 'School');
    });

    test('manual check-ins without a selected place keep the original message', () {
      final event = ActivityEvent.fromMap('circle-1', 'event-plain', {
        'type': 'checked_in',
        'actorUid': 'member-1',
        'actorName': 'Sam',
        'checkInStatus': 'im_okay',
        'occurredAt': Timestamp.now(),
      });
      expect(event!.text, "Sam shared a manual check-in: I'm okay");
      expect(event.checkInPlaceId, isNull);
      expect(event.checkInPlaceName, isNull);
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
