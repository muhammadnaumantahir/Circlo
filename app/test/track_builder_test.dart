import 'package:circlo/features/history/history_models.dart';
import 'package:circlo/features/history/track_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const homeLat = 31.5204, homeLng = 74.3587;
  const home = NamedPlace(id: 'home', name: 'Home', lat: homeLat, lng: homeLng, radiusM: 150);
  final t0 = DateTime(2026, 10, 13, 6, 0);

  double north(double m) => homeLat + m / 111000.0;
  bool feed(TrackBuilder b, double lat, double lng, int minutes, {double acc = 10, List<NamedPlace> places = const [home]}) =>
      b.process(lat: lat, lng: lng, accuracy: acc, time: t0.add(Duration(minutes: minutes)), places: places, tzOffsetMin: 0);

  test('a 5-minute pause is not a visit; a 12-minute stop at a saved place is named', () {
    final b = TrackBuilder();
    for (var m = 0; m <= 5; m++) {
      feed(b, north(10), homeLng, m);
    }
    expect(b.current!.visits, isEmpty);
    for (var m = 6; m <= 12; m++) {
      feed(b, north(10), homeLng, m);
    }
    final v = b.current!.visits.single;
    expect(v.name, 'Home');
    expect(v.placeId, 'home');
    expect(v.leftAt, isNull);
  });

  test('stops away from saved places are "Unknown place"', () {
    final b = TrackBuilder();
    for (var m = 0; m <= 12; m++) {
      feed(b, north(5000), homeLng, m);
    }
    expect(b.current!.visits.single.name, 'Unknown place');
    expect(b.current!.visits.single.placeId, isNull);
  });

  test('leaving closes the visit at the last time still there', () {
    final b = TrackBuilder();
    for (var m = 0; m <= 20; m += 2) {
      feed(b, north(10), homeLng, m);
    }
    feed(b, north(900), homeLng, 24);
    final v = b.current!.visits.single;
    expect(v.leftAt, t0.add(const Duration(minutes: 20)).millisecondsSinceEpoch);
    expect(b.current!.route.length, greaterThanOrEqualTo(2));
  });

  test('timeline like the example: home, university, home', () {
    final b = TrackBuilder();
    const uniLat = 31.5700;
    const uni = NamedPlace(id: 'uni', name: 'University', lat: uniLat, lng: homeLng, radiusM: 200);
    final places = [home, uni];
    for (var m = 0; m <= 30; m += 5) {
      feed(b, north(0), homeLng, m, places: places); // at home 6:00-6:30
    }
    for (var m = 35; m <= 60; m += 5) {
      feed(b, north(0) + (m - 30) * 0.0003, homeLng, m, places: places); // travelling
    }
    for (var m = 65; m <= 120; m += 5) {
      feed(b, uniLat, homeLng, m, places: places); // university
    }
    feed(b, north(0), homeLng, 150, places: places);
    for (var m = 155; m <= 175; m += 5) {
      feed(b, north(0), homeLng, m, places: places);
    }
    final names = [for (final v in b.current!.visits) v.name];
    expect(names, ['Home', 'University', 'Home']);
    expect(b.current!.visits[1].leftAt, isNotNull);
    expect(b.current!.visits[2].leftAt, isNull);
  });

  test('invalid GPS coordinates and accuracy are ignored without creating history', () {
    final b = TrackBuilder();
    final invalidSamples = [
      (double.nan, homeLng, 10.0),
      (91.0, homeLng, 10.0),
      (homeLat, double.infinity, 10.0),
      (homeLat, homeLng, double.nan),
      (homeLat, homeLng, double.infinity),
      (homeLat, homeLng, -1.0),
    ];

    for (final sample in invalidSamples) {
      expect(
        b.process(
          lat: sample.$1,
          lng: sample.$2,
          accuracy: sample.$3,
          time: t0,
          places: const [home],
          tzOffsetMin: 0,
        ),
        isFalse,
      );
    }
    expect(b.current, isNull);
  });

  test('an older GPS fix cannot roll history back to a previous day', () {
    final b = TrackBuilder();
    final newer = DateTime(2026, 10, 14, 0, 5);
    expect(
      b.process(
        lat: homeLat,
        lng: homeLng,
        accuracy: 10,
        time: newer,
        places: const [home],
        tzOffsetMin: 0,
      ),
      isTrue,
    );
    final current = b.current!;
    final lastSeen = current.lastSeen;
    final routeLength = current.route.length;

    expect(
      b.process(
        lat: homeLat,
        lng: homeLng,
        accuracy: 10,
        time: t0,
        places: const [home],
        tzOffsetMin: 0,
      ),
      isFalse,
    );
    expect(b.current, same(current));
    expect(b.current!.day, '20261014');
    expect(b.current!.lastSeen, lastSeen);
    expect(b.current!.route, hasLength(routeLength));
  });

  test('inaccurate fixes are ignored', () {
    final b = TrackBuilder();
    expect(feed(b, north(10), homeLng, 0, acc: 500), isFalse);
    expect(b.current, isNull);
  });

  test('route is thinned: nearby fixes do not add points; far ones do', () {
    final b = TrackBuilder();
    feed(b, north(0), homeLng, 0);
    feed(b, north(10), homeLng, 1);
    expect(b.current!.route.length, 1);
    feed(b, north(80), homeLng, 2);
    expect(b.current!.route.length, 2);
  });

  test('route never exceeds the cap', () {
    final b = TrackBuilder(maxRoutePoints: 20);
    for (var i = 0; i < 200; i++) {
      feed(b, north(i * 100.0), homeLng, i);
    }
    expect(b.current!.route.length, lessThanOrEqualTo(20));
  });

  test('day rollover starts a new DayTrack and closes the old open visit', () {
    final b = TrackBuilder();
    for (var m = 0; m <= 20; m += 2) {
      feed(b, north(10), homeLng, m);
    }
    final first = b.current!;
    expect(first.visits.single.leftAt, isNull);
    b.process(lat: north(10), lng: homeLng, accuracy: 10, time: DateTime(2026, 10, 14, 0, 5), places: const [home], tzOffsetMin: 0);
    expect(b.current!.day, '20261014');
    expect(first.visits.single.leftAt, isNotNull);
  });

  test('restore continues an open visit without duplicating it', () {
    final b = TrackBuilder();
    for (var m = 0; m <= 14; m++) {
      feed(b, north(10), homeLng, m);
    }
    final cur = b.current!;
    final saved = DayTrack(
      day: cur.day,
      tzOffsetMin: cur.tzOffsetMin,
      route: [for (final p in cur.route) TrackPoint.fromMap(p.toMap())],
      visits: [for (final v in cur.visits) Visit.fromMap(v.toMap())],
      lastSeen: cur.lastSeen,
    );
    final b2 = TrackBuilder()..restore(saved);
    for (var m = 15; m <= 30; m++) {
      feed(b2, north(10), homeLng, m);
    }
    expect(b2.current!.visits.length, 1);
  });

  test('helpers: dayKey, formatClock, formatDuration', () {
    expect(dayKey(DateTime(2026, 1, 5, 12)), '20260105');
    expect(formatClock(DateTime.utc(2026, 1, 1, 4, 5).millisecondsSinceEpoch, 300), '9:05 AM');
    expect(formatClock(DateTime.utc(2026, 1, 1, 9, 15).millisecondsSinceEpoch, 300), '2:15 PM');
    expect(formatClock(DateTime.utc(2026, 1, 1, 7, 0).millisecondsSinceEpoch, 300), '12:00 PM');
    expect(formatDuration(const Duration(hours: 5, minutes: 15)), '5 h 15 min');
    expect(formatDuration(const Duration(minutes: 40)), '40 min');
    expect(formatDuration(const Duration(hours: 2)), '2 h');
  });
}
