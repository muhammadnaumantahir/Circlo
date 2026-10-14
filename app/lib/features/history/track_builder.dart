import '../../core/geo.dart';
import 'history_models.dart';

/// A saved place with its name (the detector's PlacePoint has no name).
class NamedPlace {
  const NamedPlace({required this.id, required this.name, required this.lat, required this.lng, required this.radiusM});
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusM;
}

/// Pure logic that turns a stream of location fixes into one day's compact history:
/// a thinned route plus visits (stops of >= [minStop]). No Firebase/Flutter imports.
class TrackBuilder {
  TrackBuilder({
    this.minStop = const Duration(minutes: 10),
    this.stopRadiusM = 100,
    this.leaveRadiusM = 150,
    this.routeMinDistanceM = 50,
    this.routeMinGap = const Duration(seconds: 30),
    this.maxRoutePoints = 400,
    this.maxVisits = 60,
    this.maxAccuracyM = 100,
  });

  final Duration minStop;
  final double stopRadiusM;
  final double leaveRadiusM;
  final double routeMinDistanceM;
  final Duration routeMinGap;
  final int maxRoutePoints;
  final int maxVisits;
  final double maxAccuracyM;

  DayTrack? _track;
  double _anchorLat = 0, _anchorLng = 0;
  int? _anchorT;
  int _lastInsideT = 0;
  Visit? _open; // confirmed visit that has not ended yet

  DayTrack? get current => _track;

  /// Continue a day that was already stored (e.g. after an app restart).
  void restore(DayTrack track) {
    _track = track;
    _open = null;
    _anchorT = null;
    for (final v in track.visits.reversed) {
      if (v.leftAt == null) {
        _open = v;
        _anchorLat = v.lat;
        _anchorLng = v.lng;
        _anchorT = v.arrivedAt;
        _lastInsideT = track.lastSeen;
        break;
      }
    }
  }

  /// Closes any open visit at the last time we were still there. Call at day rollover / stop.
  void closeOpenVisit() {
    final v = _open;
    if (v != null) {
      v.leftAt = _lastInsideT > v.arrivedAt ? _lastInsideT : v.arrivedAt;
      _open = null;
    }
    _anchorT = null;
  }

  /// Returns true when the stored data changed (worth a flush).
  bool process({
    required double lat,
    required double lng,
    required double accuracy,
    required DateTime time,
    required Iterable<NamedPlace> places,
    required int tzOffsetMin,
  }) {
    if (accuracy > maxAccuracyM) return false;
    final key = dayKey(time);
    final t = time.millisecondsSinceEpoch;

    var changed = false;
    if (_track == null || _track!.day != key) {
      // New day: end yesterday's open visit; today's data starts empty and continues the stop.
      final carryOpen = _open != null;
      closeOpenVisit();
      _track = DayTrack(day: key, tzOffsetMin: tzOffsetMin);
      if (carryOpen) {
        _anchorT = null; // a fresh stop candidate begins with this fix
      }
      changed = true;
    }
    final track = _track!;
    track.lastSeen = t;

    // ---- route (thinned) ----
    final last = track.route.isEmpty ? null : track.route.last;
    if (last == null ||
        (distanceMeters(last.lat, last.lng, lat, lng) >= routeMinDistanceM &&
            t - last.t >= routeMinGap.inMilliseconds)) {
      track.route.add(TrackPoint(lat: lat, lng: lng, t: t));
      if (track.route.length > maxRoutePoints) {
        // keep first + last, drop every other point in between
        final kept = <TrackPoint>[];
        for (var i = 0; i < track.route.length; i++) {
          if (i == 0 || i == track.route.length - 1 || i.isEven) kept.add(track.route[i]);
        }
        track.route
          ..clear()
          ..addAll(kept);
      }
      changed = true;
    }

    // ---- stops ----
    final open = _open;
    if (open != null) {
      if (distanceMeters(_anchorLat, _anchorLng, lat, lng) <= leaveRadiusM) {
        _lastInsideT = t;
      } else {
        open.leftAt = _lastInsideT > open.arrivedAt ? _lastInsideT : open.arrivedAt;
        _open = null;
        _anchorLat = lat;
        _anchorLng = lng;
        _anchorT = t;
        _lastInsideT = t;
        changed = true;
      }
    } else {
      if (_anchorT == null || distanceMeters(_anchorLat, _anchorLng, lat, lng) > stopRadiusM) {
        _anchorLat = lat;
        _anchorLng = lng;
        _anchorT = t;
        _lastInsideT = t;
      } else {
        _lastInsideT = t;
        if (t - _anchorT! >= minStop.inMilliseconds && track.visits.length < maxVisits) {
          NamedPlace? at;
          for (final p in places) {
            if (distanceMeters(_anchorLat, _anchorLng, p.lat, p.lng) <= p.radiusM) {
              at = p;
              break;
            }
          }
          final v = Visit(
            placeId: at?.id,
            name: at?.name ?? 'Unknown place',
            lat: _anchorLat,
            lng: _anchorLng,
            arrivedAt: _anchorT!,
          );
          track.visits.add(v);
          _open = v;
          changed = true;
        }
      }
    }
    return changed;
  }
}
