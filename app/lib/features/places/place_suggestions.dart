import '../../core/geo.dart';
import '../history/history_models.dart';
import 'place_models.dart';

/// A place candidate inferred from repeat visits in the user's own private travel history.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.lat,
    required this.lng,
    required this.visitCount,
    required this.distinctDays,
    required this.lastVisitedAt,
  });

  final double lat;
  final double lng;
  final int visitCount;
  final int distinctDays;
  final int lastVisitedAt; // epoch milliseconds
}

class _DatedVisit {
  const _DatedVisit(this.day, this.visit);
  final String day;
  final Visit visit;
}

class _VisitCluster {
  final List<_DatedVisit> entries = [];

  double get lat => entries.fold<double>(0, (sum, e) => sum + e.visit.lat) / entries.length;
  double get lng => entries.fold<double>(0, (sum, e) => sum + e.visit.lng) / entries.length;

  void add(_DatedVisit entry) => entries.add(entry);
}

/// Finds unknown stops repeated on at least two different days, without a paid geocoder.
///
/// Only completed 'Unknown place' visits are considered. Candidates already within a saved
/// circle place's radius (plus a safety margin) are excluded. History stays private; callers
/// decide which circle's existing saved places should suppress duplicates.
List<PlaceSuggestion> findPlaceSuggestions({
  required Iterable<DayTrack> tracks,
  required Iterable<Place> savedPlaces,
  int minimumDays = 2,
  double clusterRadiusM = 150,
  int limit = 5,
}) {
  if (minimumDays < 2 || clusterRadiusM <= 0 || limit < 1) return const [];

  final clusters = <_VisitCluster>[];
  final candidates = <_DatedVisit>[];
  for (final track in tracks) {
    for (final visit in track.visits) {
      if (visit.placeId != null ||
          visit.name.trim().toLowerCase() != 'unknown place' ||
          visit.leftAt == null ||
          visit.leftAt! <= visit.arrivedAt ||
          visit.leftAt! - visit.arrivedAt < const Duration(minutes: 10).inMilliseconds) {
        continue;
      }
      candidates.add(_DatedVisit(track.day, visit));
    }
  }
  candidates.sort((a, b) => a.visit.arrivedAt.compareTo(b.visit.arrivedAt));

  for (final entry in candidates) {
    _VisitCluster? closest;
    var bestDistance = double.infinity;
    for (final cluster in clusters) {
      final distance = distanceMeters(entry.visit.lat, entry.visit.lng, cluster.lat, cluster.lng);
      if (distance <= clusterRadiusM && distance < bestDistance) {
        bestDistance = distance;
        closest = cluster;
      }
    }
    if (closest == null) {
      clusters.add(_VisitCluster()..add(entry));
    } else {
      closest.add(entry);
    }
  }

  final suggestions = <PlaceSuggestion>[];
  for (final cluster in clusters) {
    final days = cluster.entries.map((e) => e.day).toSet();
    if (days.length < minimumDays) continue;

    final alreadySaved = savedPlaces.any((place) =>
        distanceMeters(cluster.lat, cluster.lng, place.lat, place.lng) <= place.radiusM + 50);
    if (alreadySaved) continue;

    suggestions.add(PlaceSuggestion(
      lat: cluster.lat,
      lng: cluster.lng,
      visitCount: cluster.entries.length,
      distinctDays: days.length,
      lastVisitedAt: cluster.entries.map((e) => e.visit.arrivedAt).reduce((a, b) => a > b ? a : b),
    ));
  }

  suggestions.sort((a, b) {
    final visits = b.visitCount.compareTo(a.visitCount);
    return visits != 0 ? visits : b.lastVisitedAt.compareTo(a.lastVisitedAt);
  });
  return suggestions.take(limit).toList(growable: false);
}
