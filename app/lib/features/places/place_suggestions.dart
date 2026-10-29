import '../../core/geo.dart';
import '../history/history_models.dart';
import 'place_models.dart';

const int kMinimumSuggestedVisits = 3;
const int kMinimumSuggestedDays = 3;
const double kSuggestionClusterRadiusM = 150;
const double kSuggestionPlaceExclusionBufferM = 75;

/// A private, on-device candidate derived from the signed-in user's own opt-in history.
/// Suggestions are not written to Firestore; they become circle-visible only if the user saves one.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.lat,
    required this.lng,
    required this.visitCount,
    required this.distinctDayCount,
    required this.lastVisitedAt,
    required this.suggestedName,
  });

  final String id;
  final double lat;
  final double lng;
  final int visitCount;
  final int distinctDayCount;
  final DateTime lastVisitedAt;
  final String suggestedName;
}

class _SuggestionCluster {
  _SuggestionCluster(Visit first, String day) : lat = first.lat, lng = first.lng {
    add(first, day);
  }

  double lat;
  double lng;
  int visitCount = 0;
  final Set<String> days = <String>{};
  final Map<String, int> labels = <String, int>{};
  int lastVisitedAtMs = 0;

  void add(Visit visit, String day) {
    final oldCount = visitCount;
    visitCount++;
    lat = ((lat * oldCount) + visit.lat) / visitCount;
    lng = ((lng * oldCount) + visit.lng) / visitCount;
    days.add(day);
    if (visit.arrivedAt > lastVisitedAtMs) lastVisitedAtMs = visit.arrivedAt;

    final label = visit.name.trim();
    if (label.isNotEmpty && label.toLowerCase() != 'unknown place') {
      labels[label] = (labels[label] ?? 0) + 1;
    }
  }

  PlaceSuggestion toSuggestion() {
    final sortedLabels = labels.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    // Round only for a stable, session-level dismiss key. Coordinates remain full precision
    // for the user's review form; the key is never uploaded or persisted.
    final id = '${(lat * 10000).round()}_${(lng * 10000).round()}';
    return PlaceSuggestion(
      id: id,
      lat: lat,
      lng: lng,
      visitCount: visitCount,
      distinctDayCount: days.length,
      lastVisitedAt: DateTime.fromMillisecondsSinceEpoch(lastVisitedAtMs),
      suggestedName: sortedLabels.isEmpty ? 'Frequent stop' : sortedLabels.first.key,
    );
  }
}

/// Finds repeated, unlabeled stops from private history only.
///
/// Requirements:
/// - at least [kMinimumSuggestedVisits] visits across [kMinimumSuggestedDays] different days;
/// - a stop must last at least ten minutes (the history recorder's stop contract);
/// - places already saved in this circle are excluded using their configured radius plus a buffer;
/// - output is local-only. Calling this function never saves, shares or publishes coordinates.
List<PlaceSuggestion> buildPlaceSuggestions({
  required Iterable<DayTrack> tracks,
  required Iterable<Place> savedPlaces,
  DateTime? now,
  int minimumVisits = kMinimumSuggestedVisits,
  int minimumDays = kMinimumSuggestedDays,
  double clusterRadiusM = kSuggestionClusterRadiusM,
  int limit = 5,
}) {
  if (minimumVisits < 1 || minimumDays < 1 || clusterRadiusM <= 0 || limit < 1) {
    throw ArgumentError('Suggestion thresholds must be positive.');
  }

  final places = savedPlaces.toList(growable: false);
  final clusters = <_SuggestionCluster>[];
  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
  const minimumStopMs = Duration(minutes: 10).inMilliseconds;

  for (final track in tracks) {
    final day = track.day.length == 8 ? track.day : _dayKey(DateTime.fromMillisecondsSinceEpoch(track.lastSeen));
    for (final visit in track.visits) {
      if ((visit.placeId ?? '').trim().isNotEmpty) continue;
      if (!visit.lat.isFinite || !visit.lng.isFinite ||
          visit.lat < -90 || visit.lat > 90 || visit.lng < -180 || visit.lng > 180) {
        continue;
      }

      final endMs = visit.leftAt ?? nowMs;
      final durationMs = endMs - visit.arrivedAt;
      if (durationMs < minimumStopMs || durationMs < 0) continue;

      final nearSavedPlace = places.any((place) =>
          distanceMeters(visit.lat, visit.lng, place.lat, place.lng) <=
          place.radiusM + kSuggestionPlaceExclusionBufferM);
      if (nearSavedPlace) continue;

      _SuggestionCluster? closest;
      var closestDistance = double.infinity;
      for (final cluster in clusters) {
        final distance = distanceMeters(visit.lat, visit.lng, cluster.lat, cluster.lng);
        if (distance <= clusterRadiusM && distance < closestDistance) {
          closest = cluster;
          closestDistance = distance;
        }
      }
      if (closest == null) {
        clusters.add(_SuggestionCluster(visit, day));
      } else {
        closest.add(visit, day);
      }
    }
  }

  final suggestions = <PlaceSuggestion>[];
  for (final cluster in clusters) {
    if (cluster.visitCount < minimumVisits || cluster.days.length < minimumDays) continue;
    if (places.any((place) =>
        distanceMeters(cluster.lat, cluster.lng, place.lat, place.lng) <=
        place.radiusM + kSuggestionPlaceExclusionBufferM)) {
      continue;
    }
    suggestions.add(cluster.toSuggestion());
  }

  suggestions.sort((a, b) {
    final days = b.distinctDayCount.compareTo(a.distinctDayCount);
    if (days != 0) return days;
    final visits = b.visitCount.compareTo(a.visitCount);
    if (visits != 0) return visits;
    return b.lastVisitedAt.compareTo(a.lastVisitedAt);
  });
  return List<PlaceSuggestion>.unmodifiable(suggestions.take(limit));
}

String _dayKey(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}${time.month.toString().padLeft(2, '0')}${time.day.toString().padLeft(2, '0')}';
