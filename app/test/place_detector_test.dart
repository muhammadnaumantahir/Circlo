import 'package:circlo/core/geo.dart';
import 'package:circlo/features/places/place_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const school = PlacePoint(id: 'school', lat: 31.5204, lng: 74.3587, radiusM: 150);
  final t0 = DateTime(2026, 10, 13, 8, 0);

  // ~0.001 degrees latitude is ~111 m.
  Fix at(double metersNorth, int seconds, {double acc = 10}) => Fix(
        lat: school.lat + metersNorth / 111000.0,
        lng: school.lng,
        accuracy: acc,
        time: t0.add(Duration(seconds: seconds)),
      );

  test('distanceMeters is roughly right', () {
    expect(distanceMeters(0, 0, 0, 0), 0);
    expect(distanceMeters(31.5204, 74.3587, 31.5214, 74.3587), closeTo(111, 3));
  });

  test('one fix inside is not enough; second consecutive fix produces exactly one arrival', () {
    final d = PlaceDetector();
    expect(d.process(at(400, 0), [school]), isEmpty);
    expect(d.process(at(100, 30), [school]), isEmpty);
    final out = d.process(at(80, 60), [school]);
    expect(out.length, 1);
    expect(out.first.type, TransitionType.arrive);
    expect(d.process(at(50, 90), [school]), isEmpty); // still inside: no repeat
    expect(d.process(at(20, 120), [school]), isEmpty);
  });

  test('two inside fixes far apart in time (stationary heartbeat) still confirm one arrival', () {
    final d = PlaceDetector();
    expect(d.process(at(100, 0), [school]), isEmpty);
    // fix goes back outside would reset; here the next fix is again inside after 2 min but count==2 anyway
    final out = d.process(at(100, 130), [school]);
    expect(out.single.type, TransitionType.arrive);
  });

  test('GPS jitter around the boundary does not create repeated events', () {
    final d = PlaceDetector();
    d.process(at(100, 0), [school]);
    d.process(at(100, 20), [school]); // arrived
    var count = 0;
    // wobble between 140 m and 170 m: inside the exit threshold (150 * 1.2 = 180)
    for (var i = 0; i < 20; i++) {
      count += d.process(at(i.isEven ? 140 : 170, 40 + i * 10), [school]).length;
    }
    expect(count, 0);
  });

  test('leaving needs two consecutive fixes beyond 1.2 x radius; produces one departure with the same visit id', () {
    final d = PlaceDetector();
    d.process(at(50, 0), [school]);
    final arrive = d.process(at(50, 20), [school]).single;
    expect(d.process(at(300, 60), [school]), isEmpty);
    final leave = d.process(at(320, 90), [school]).single;
    expect(leave.type, TransitionType.leave);
    expect(leave.visitId, arrive.visitId);
    expect(d.process(at(400, 120), [school]), isEmpty);
  });

  test('a brief excursion (one outside fix) does not end the visit', () {
    final d = PlaceDetector();
    d.process(at(50, 0), [school]);
    d.process(at(50, 20), [school]);
    expect(d.process(at(300, 40), [school]), isEmpty);
    expect(d.process(at(60, 60), [school]), isEmpty); // back inside resets the pending departure
    expect(d.process(at(300, 80), [school]), isEmpty);
  });

  test('malformed GPS fixes are ignored without changing visit state', () {
    final d = PlaceDetector();
    expect(d.process(const Fix(lat: double.nan, lng: school.lng, accuracy: 5, time: t0), [school]), isEmpty);
    expect(d.process(const Fix(lat: 91, lng: school.lng, accuracy: 5, time: t0), [school]), isEmpty);
    expect(d.process(const Fix(lat: school.lat, lng: school.lng, accuracy: double.nan, time: t0), [school]), isEmpty);
    expect(d.process(const Fix(lat: school.lat, lng: school.lng, accuracy: -1, time: t0), [school]), isEmpty);
    expect(d.isInside('school'), isFalse);

    // Two valid samples are still required; rejected samples do not count toward confirmation.
    expect(d.process(at(10, 10), [school]), isEmpty);
    expect(d.process(at(10, 20), [school]).single.type, TransitionType.arrive);
  });

  test('out-of-order fixes do not count toward arrival confirmation', () {
    final d = PlaceDetector();
    expect(d.process(at(10, 20), [school]), isEmpty);
    // This sample is older than the previous one and must not confirm arrival.
    expect(d.process(at(10, 10), [school]), isEmpty);
    expect(d.isInside('school'), isFalse);
    expect(d.process(at(10, 30), [school]).single.type, TransitionType.arrive);
  });

  test('duplicate timestamps do not count as separate confirmation fixes', () {
    final d = PlaceDetector();
    final first = at(10, 20);
    final duplicate = Fix(
      lat: first.lat,
      lng: first.lng,
      accuracy: first.accuracy,
      time: first.time,
    );

    expect(d.process(first, [school]), isEmpty);
    expect(d.process(duplicate, [school]), isEmpty);
    expect(d.isInside('school'), isFalse);

    expect(d.process(at(10, 30), [school]).single.type, TransitionType.arrive);
  });

  test('same place document ID in different circles has independent state', () {
    final d = PlaceDetector();
    const homeA = PlacePoint(id: 'circle-a/home', lat: school.lat, lng: school.lng, radiusM: 150);
    const homeB = PlacePoint(id: 'circle-b/home', lat: school.lat, lng: school.lng, radiusM: 150);

    expect(d.process(at(10, 0), [homeA]), isEmpty);
    expect(d.process(at(10, 10), [homeB]), isEmpty);
    expect(d.process(at(10, 20), [homeA]).single.type, TransitionType.arrive);
    expect(d.isInside('circle-a/home'), isTrue);
    expect(d.isInside('circle-b/home'), isFalse);
    expect(d.process(at(10, 30), [homeB]).single.type, TransitionType.arrive);
    expect(d.isInside('circle-b/home'), isTrue);
  });

  test('invalid saved place coordinates and radii are ignored', () {
    final d = PlaceDetector();
    const invalidPlaces = [
      PlacePoint(id: 'bad-lat', lat: 91, lng: school.lng, radiusM: 150),
      PlacePoint(id: 'bad-lng', lat: school.lat, lng: double.infinity, radiusM: 150),
      PlacePoint(id: 'bad-radius', lat: school.lat, lng: school.lng, radiusM: double.nan),
      PlacePoint(id: 'negative-radius', lat: school.lat, lng: school.lng, radiusM: -10),
    ];
    expect(d.process(at(10, 10), invalidPlaces), isEmpty);
    expect(d.process(at(10, 20), invalidPlaces), isEmpty);
    for (final place in invalidPlaces) {
      expect(d.isInside(place.id), isFalse);
    }
  });

  test('inaccurate fixes are ignored', () {
    final d = PlaceDetector();
    expect(d.process(at(10, 0, acc: 500), [school]), isEmpty);
    expect(d.process(at(10, 20, acc: 500), [school]), isEmpty);
    expect(d.isInside('school'), isFalse);
  });

  test('restoreInside prevents a duplicate arrival after restart', () {
    final d = PlaceDetector()..restoreInside('school', '123');
    expect(d.process(at(10, 0), [school]), isEmpty);
    expect(d.process(at(10, 20), [school]), isEmpty);
    d.process(at(400, 60), [school]);
    final leave = d.process(at(400, 90), [school]).single;
    expect(leave.visitId, '123');
  });

  test('a second visit gets a new visit id', () {
    final d = PlaceDetector();
    d.process(at(10, 0), [school]);
    final a1 = d.process(at(10, 20), [school]).single;
    d.process(at(500, 60), [school]);
    d.process(at(500, 80), [school]);
    d.process(at(10, 3600), [school]);
    final a2 = d.process(at(10, 3620), [school]).single;
    expect(a2.type, TransitionType.arrive);
    expect(a2.visitId, isNot(a1.visitId));
  });


  test('restoring a latest departure clears stale inside state and visit id', () {
    final d = PlaceDetector()..restoreInside('school', 'old-visit');
    expect(d.isInside('school'), isTrue);

    d.restoreState('school', inside: false);
    expect(d.isInside('school'), isFalse);

    // Outside fixes after restoration must not emit a second departure for old-visit.
    expect(d.process(at(400, 0), [school]), isEmpty);
    expect(d.process(at(420, 30), [school]), isEmpty);

    // A later visit begins as a completely new visit.
    expect(d.process(at(80, 60), [school]), isEmpty);
    final arrive = d.process(at(70, 90), [school]).single;
    expect(arrive.type, TransitionType.arrive);
    expect(arrive.visitId, isNot('old-visit'));
  });

  test('retainOnly drops state of deleted places', () {
    final d = PlaceDetector()..restoreInside('school', '1');
    d.retainOnly({});
    expect(d.isInside('school'), isFalse);
  });
}
