import 'package:circlo/features/places/no_show_alerts.dart';
import 'package:circlo/features/places/place_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 29, 15, 0);
  final cutoff = now.subtract(const Duration(days: 30));
  final expectedAt = now.subtract(const Duration(minutes: 10));
  final createdAt = expectedAt.subtract(const Duration(hours: 1));
  const place = Place(
    id: 'school',
    circleId: 'c1',
    name: 'School',
    lat: 31.52,
    lng: 74.35,
    radiusM: 150,
    createdBy: 'owner',
  );

  ArrivalPlan plan({
    DateTime? expected,
    DateTime? created,
    String status = 'pending',
    DateTime? arrived,
  }) =>
      ArrivalPlan(
        id: 'member1',
        circleId: 'c1',
        memberUid: 'member1',
        placeId: 'school',
        expectedAt: expected ?? expectedAt,
        status: status,
        createdAt: created ?? createdAt,
        arrivedAt: arrived,
      );

  NoShowAlert? evaluate({
    ArrivalPlan? arrivalPlan,
    DateTime? latestLocationAt,
    Iterable<PlaceEvent> events = const <PlaceEvent>[],
    String viewerUid = 'member2',
    String? memberName = 'Sam',
    bool sharesLocation = true,
    bool paused = false,
    Place? targetPlace = place,
    DateTime? at,
  }) =>
      evaluateNoShowAlert(
        circleId: 'c1',
        viewerUid: viewerUid,
        plan: arrivalPlan ?? plan(),
        memberName: memberName,
        memberSharesLocation: sharesLocation,
        memberPaused: paused,
        place: targetPlace,
        latestLocationAt: latestLocationAt,
        recentPlaceEvents: events,
        now: at ?? now,
        cutoff: cutoff,
      );

  test('does not generate a No Show before the expected time', () {
    final result = evaluate(
      arrivalPlan: plan(expected: now.add(const Duration(minutes: 5))),
      latestLocationAt: now,
    );
    expect(result, isNull);
  });

  test('generates a stable overdue item when location is fresh', () {
    final result = evaluate(latestLocationAt: now.subtract(const Duration(minutes: 5)));
    expect(result, isNotNull);
    expect(result!.id, 'c1/no-show/member1');
    expect(result.at, expectedAt);
    expect(result.text, 'Sam has no arrival recorded at School by the expected time.');
    expect(result.text, isNot(contains('location may be unavailable')));
  });

  test('labels missing or stale location as potentially unavailable', () {
    final noLocation = evaluate();
    final oldLocation = evaluate(latestLocationAt: now.subtract(const Duration(minutes: 16)));
    expect(noLocation!.text, contains('location may be unavailable'));
    expect(oldLocation!.text, contains('location may be unavailable'));
  });

  test('does not trust a location timestamp more than two minutes in the future', () {
    final result = evaluate(latestLocationAt: now.add(const Duration(minutes: 5)));
    expect(result, isNotNull);
    expect(result!.text, contains('location may be unavailable'));
  });

  test('suppresses No Show when the place detector recorded an on-time arrival', () {
    final event = PlaceEvent(
      id: 'event1',
      circleId: 'c1',
      placeId: 'school',
      placeName: 'School',
      memberUid: 'member1',
      memberName: 'Sam',
      type: 'arrive',
      visitId: 'visit1',
      occurredAt: expectedAt,
    );
    expect(evaluate(events: [event]), isNull);
  });

  test('preserves a late-arrival event if completing the plan failed', () {
    final arrivalTime = expectedAt.add(const Duration(minutes: 8));
    final event = PlaceEvent(
      id: 'event2',
      circleId: 'c1',
      placeId: 'school',
      placeName: 'School',
      memberUid: 'member1',
      memberName: 'Sam',
      type: 'arrive',
      visitId: 'visit2',
      occurredAt: arrivalTime,
    );
    final result = evaluate(events: [event]);
    expect(result!.id, 'c1/no-show-late-event/member1');
    expect(result.at, arrivalTime);
    expect(result.text, contains('arriving at School after the expected time'));
  });

  test('reports persisted late arrivals once and ignores on-time completions', () {
    final lateAt = expectedAt.add(const Duration(minutes: 12));
    final late = evaluate(arrivalPlan: plan(status: 'arrived', arrived: lateAt));
    expect(late!.id, 'c1/no-show-late/member1');
    expect(late.at, lateAt);

    final onTime = evaluate(
      arrivalPlan: plan(status: 'arrived', arrived: expectedAt),
    );
    expect(onTime, isNull);
  });

  test('suppresses alerts for own plans, paused members and inactive sharing', () {
    expect(evaluate(viewerUid: 'member1'), isNull);
    expect(evaluate(paused: true), isNull);
    expect(evaluate(sharesLocation: false), isNull);
    expect(evaluate(memberName: null), isNull);
    expect(evaluate(targetPlace: null), isNull);
  });

  test('drops overdue plans outside the 30-day feed window', () {
    final old = plan(expected: now.subtract(const Duration(days: 31)));
    expect(evaluate(arrivalPlan: old), isNull);
  });
}
