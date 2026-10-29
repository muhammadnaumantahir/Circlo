import 'package:circlo/features/history/history_models.dart';
import 'package:circlo/features/places/place_models.dart';
import 'package:circlo/features/places/place_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DayTrack day(String key, List<Visit> visits) => DayTrack(
        day: key,
        tzOffsetMin: 0,
        visits: visits,
      );

  Visit stop(double lat, double lng, int t, {int minutes = 20, String name = 'Unknown place', String? placeId}) =>
      Visit(
        lat: lat,
        lng: lng,
        name: name,
        placeId: placeId,
        arrivedAt: t,
        leftAt: t + Duration(minutes: minutes).inMilliseconds,
      );

  Place savedPlace({double lat = 31.5204, double lng = 74.3587, double radius = 150}) => Place(
        id: 'p1',
        circleId: 'c1',
        name: 'Home',
        lat: lat,
        lng: lng,
        radiusM: radius,
        createdBy: 'u1',
      );

  test('suggests completed unknown stops repeated across separate days', () {
    final suggestions = findPlaceSuggestions(
      tracks: [
        day('20261027', [stop(31.5204, 74.3587, 1000000)]),
        day('20261028', [stop(31.5205, 74.3588, 2000000)]),
      ],
      savedPlaces: [],
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.visitCount, 2);
    expect(suggestions.single.distinctDays, 2);
    expect(suggestions.single.lat, closeTo(31.52045, .0001));
  });

  test('ignores same-day repeats, open stops, named stops, and short stops', () {
    final suggestions = findPlaceSuggestions(
      tracks: [
        day('20261028', [
          stop(31.52, 74.35, 1000000),
          stop(31.5201, 74.3501, 2000000),
          stop(31.52, 74.35, 3000000, name: 'Office'),
          stop(31.52, 74.35, 4000000, minutes: 5),
          Visit(name: 'Unknown place', lat: 31.52, lng: 74.35, arrivedAt: 5000000),
        ]),
      ],
      savedPlaces: [],
    );
    expect(suggestions, isEmpty);
  });

  test('does not suggest a stop already covered by a saved place', () {
    final suggestions = findPlaceSuggestions(
      tracks: [
        day('20261027', [stop(31.5204, 74.3587, 1000000)]),
        day('20261028', [stop(31.5205, 74.3588, 2000000)]),
      ],
      savedPlaces: [savedPlace()],
    );
    expect(suggestions, isEmpty);
  });

  test('keeps distinct nearby stops separate and returns most frequent first', () {
    final suggestions = findPlaceSuggestions(
      tracks: [
        day('20261025', [stop(31.52, 74.35, 1000000), stop(31.54, 74.37, 3000000)]),
        day('20261026', [stop(31.5201, 74.3501, 5000000), stop(31.5401, 74.3701, 7000000)]),
        day('20261027', [stop(31.5202, 74.3502, 9000000)]),
      ],
      savedPlaces: [],
    );
    expect(suggestions, hasLength(2));
    expect(suggestions.first.visitCount, 3);
    expect(suggestions.last.visitCount, 2);
  });
}
