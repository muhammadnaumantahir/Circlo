import 'package:circlo/features/places/activity_time_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activityTimeGroupLabel', () {
    final now = DateTime(2026, 10, 28, 23, 30);

    test('groups events on the same local calendar date as Today', () {
      expect(
        activityTimeGroupLabel(DateTime(2026, 10, 28, 1), now: now),
        'Today',
      );
    });

    test('groups the previous calendar date as Yesterday', () {
      expect(
        activityTimeGroupLabel(DateTime(2026, 10, 27, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('groups events from two to six days ago as Last 7 days', () {
      expect(activityTimeGroupLabel(DateTime(2026, 10, 26), now: now), 'Last 7 days');
      expect(activityTimeGroupLabel(DateTime(2026, 10, 22), now: now), 'Last 7 days');
    });

    test('groups events seven or more days ago as Earlier', () {
      expect(activityTimeGroupLabel(DateTime(2026, 10, 21, 23, 59), now: now), 'Earlier');
    });

    test('labels future calendar dates as Upcoming', () {
      expect(activityTimeGroupLabel(DateTime(2026, 10, 29, 0, 1), now: now), 'Upcoming');
    });
  });
}
