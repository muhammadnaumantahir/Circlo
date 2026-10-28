import 'package:circlo/features/history/history_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DayTrack.fromMap', () {
    test('keeps valid history entries and skips malformed nested records', () {
      final track = DayTrack.fromMap({
        'day': '20261029',
        'tzOffsetMin': 'invalid',
        'lastSeen': 'invalid',
        'updatedAt': 'not-a-timestamp',
        'route': [
          {'lat': 31.52, 'lng': 74.35, 't': 1000},
          {'lat': 'invalid', 'lng': 74.35, 't': 2000},
          {'lat': 91, 'lng': 74.35, 't': 3000},
          'not-a-map',
        ],
        'visits': [
          {
            'name': 'Home',
            'lat': 31.52,
            'lng': 74.35,
            'arrivedAt': 1000,
            'leftAt': 2000,
          },
          {
            'name': 'Broken coordinates',
            'lat': 'invalid',
            'lng': 74.35,
            'arrivedAt': 1000,
          },
          {
            'name': 'Broken time',
            'lat': 31.52,
            'lng': 74.35,
            'arrivedAt': 1000,
            'leftAt': 'invalid',
          },
          'not-a-map',
        ],
      });

      expect(track.day, '20261029');
      expect(track.tzOffsetMin, 0);
      expect(track.lastSeen, 0);
      expect(track.updatedAt, isNull);
      expect(track.route, hasLength(1));
      expect(track.route.single.t, 1000);
      expect(track.visits, hasLength(1));
      expect(track.visits.single.name, 'Home');
      expect(track.visits.single.leftAt, 2000);
    });

    test('malformed collection fields safely become empty collections', () {
      final track = DayTrack.fromMap({
        'day': 42,
        'tzOffsetMin': 'bad',
        'lastSeen': double.infinity,
        'route': 'not-a-list',
        'visits': {'not': 'a list'},
      });

      expect(track.day, '');
      expect(track.tzOffsetMin, 0);
      expect(track.lastSeen, 0);
      expect(track.route, isEmpty);
      expect(track.visits, isEmpty);
    });
  });

  group('history item tryFromMap', () {
    test('rejects invalid point coordinates and timestamps', () {
      expect(TrackPoint.tryFromMap({'lat': 91, 'lng': 0, 't': 1}), isNull);
      expect(TrackPoint.tryFromMap({'lat': 0, 'lng': 0, 't': double.nan}), isNull);
    });

    test('rejects visits with malformed timestamps or reversed duration', () {
      expect(Visit.tryFromMap({
        'name': 'Home',
        'lat': 0,
        'lng': 0,
        'arrivedAt': 20,
        'leftAt': 10,
      }), isNull);
      expect(Visit.tryFromMap({
        'name': 'Home',
        'lat': 0,
        'lng': 0,
        'arrivedAt': 'invalid',
      }), isNull);
    });
  });
}
