import 'package:circlo/features/history/history_models.dart';
import 'package:circlo/features/places/place_models.dart';
import 'package:circlo/features/places/place_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 29, 12);

  Visit stop({
    required DateTime arrived,
    DateTime? left,
    double lat = 31.5204,
    double lng = 74.3587,
    String? placeId,
    String name = 'Unknown place',
  }) =>
      Visit(
        placeId: placeId,
        name: name,
        lat: lat,
        lng: lng,
        arrivedAt: arrived.millisecondsSinceEpoch,
        leftAt: left?.millisecondsSinceEpoch,
      );

  DayTrack day(String key, List<Visit> visits) =>
      DayTrack(day: key, tzOffsetMin: 300, visits: visits);

  test('suggests an unlabeled stop visited on at least three distinct days', () {
    final candidate = buildPlaceSuggestions(
      tracks: [
        day('20261027', [stop(arrived: DateTime(2026, 10, 27, 8), left: DateTime(2026, 10, 27, 8, 45))]),
        day('20261028', [stop(arrived: DateTime(2026, 10, 28, 8), left: DateTime(2026, 10, 28, 8, 45), lat: 31.52045)]),
        day('20261029', [stop(arrived: DateTime(2026, 10, 29, 8), left: DateTime(2026, 10, 29, 8, 45), lng: 74.35875)]),
      ],
      savedPlaces: const <Place>[],
      now: now,
    );

    expect(candidate, hasLength(1));
    expect(candidate.single.visitCount, 3);
    expect(candidate.single.distinctDayCount, 3);
    expect(candidate.single.suggestedName, 'Frequent stop');
    expect(candidate.single.lastVisitedAt.day, 29);
  });

  test('does not suggest a stop repeated on fewer than three distinct days', () {
    final candidates = buildPlaceSuggestions(
      tracks: [
        day('20261028', [
          stop(arrived: DateTime(2026, 10, 28, 8), left: DateTime(2026, 10, 28, 8, 45)),
          stop(arrived: DateTime(2026, 10, 28, 14), left: DateTime(2026, 10, 28, 14, 45), lat: 31.52045),
        ]),
        day('20261029', [stop(arrived: DateTime(2026, 10, 29, 8), left: DateTime(2026, 10, 29, 8, 45))]),
      ],
      savedPlaces: const <Place>[],
      now: now,
    );

    expect(candidates, isEmpty);
  });

  test('does not suggest a visit already associated with a saved place', () {
    final candidates = buildPlaceSuggestions(
      tracks: [
        for (var dayIndex = 27; dayIndex <= 29; dayIndex++)
          day('202610$dayIndex', [
            stop(
              arrived: DateTime(2026, 10, dayIndex, 8),
              left: DateTime(2026, 10, dayIndex, 8, 45),
              placeId: 'school',
              name: 'School',
            ),
          ]),
      ],
      savedPlaces: const <Place>[],
      now: now,
    );

    expect(candidates, isEmpty);
  });

  test('excludes candidates already covered by a saved place radius', () {
    const saved = Place(
      id: 'home',
      circleId: 'c1',
      name: 'Home',
      lat: 31.5204,
      lng: 74.3587,
      radiusM: 150,
      createdBy: 'u1',
    );
    final candidates = buildPlaceSuggestions(
      tracks: [
        for (var dayIndex = 27; dayIndex <= 29; dayIndex++)
          day('202610$dayIndex', [
            stop(
              arrived: DateTime(2026, 10, dayIndex, 8),
              left: DateTime(2026, 10, dayIndex, 8, 45),
            ),
          ]),
      ],
      savedPlaces: const [saved],
      now: now,
    );

    expect(candidates, isEmpty);
  });

  test('ignores short stops and limits the number of suggestions', () {
    final tracks = [
      for (var dayIndex = 20; dayIndex <= 29; dayIndex++)
        day('202610$dayIndex', [
          stop(
            arrived: DateTime(2026, 10, dayIndex, 8),
            left: DateTime(2026, 10, dayIndex, 8, 5),
          ),
        ]),
      for (var cluster = 0; cluster < 7; cluster++)
        for (var dayIndex = 20; dayIndex <= 29; dayIndex++)
          day(
            '202610$dayIndex',
            [
              stop(
                arrived: DateTime(2026, 10, dayIndex, 9),
                left: DateTime(2026, 10, dayIndex, 10),
                lat: 31.52 + cluster * 0.01,
                lng: 74.35 + cluster * 0.01,
              ),
            ],
          ),
    ];

    final suggestions = buildPlaceSuggestions(
      tracks: tracks,
      savedPlaces: const <Place>[],
      now: now,
      limit: 5,
    );

    expect(suggestions, hasLength(5));
    expect(suggestions.every((item) => item.visitCount >= 3 && item.distinctDayCount >= 3), isTrue);
  });
}
