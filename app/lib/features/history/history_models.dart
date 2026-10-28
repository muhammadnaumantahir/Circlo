import 'package:cloud_firestore/cloud_firestore.dart';

// Keep epoch values within DateTime's supported range, with room for a legal UTC offset.
const int _maxSafeEpochMs = 8640000000000000 - (14 * 60 * 60 * 1000);
const int _maxTimezoneOffsetMin = 14 * 60;

int? _safeInt(Object? value) {
  if (value is! num) return null;
  final number = value.toDouble();
  if (!number.isFinite || number < -_maxSafeEpochMs || number > _maxSafeEpochMs) {
    return null;
  }
  return value.toInt();
}

int _safeTimezoneOffset(Object? value) {
  final offset = _safeInt(value);
  if (offset == null || offset < -_maxTimezoneOffsetMin || offset > _maxTimezoneOffsetMin) {
    return 0;
  }
  return offset;
}

bool _validCoordinates(double lat, double lng) =>
    lat.isFinite && lng.isFinite && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

Map<String, dynamic>? _stringKeyedMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}

class TrackPoint {
  const TrackPoint({required this.lat, required this.lng, required this.t});
  final double lat;
  final double lng;
  final int t; // epoch milliseconds

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 't': t};

  static TrackPoint? tryFromMap(Map<String, dynamic> m) {
    final rawLat = m['lat'];
    final rawLng = m['lng'];
    final t = _safeInt(m['t']);
    if (rawLat is! num || rawLng is! num || t == null) return null;

    final lat = rawLat.toDouble();
    final lng = rawLng.toDouble();
    if (!_validCoordinates(lat, lng)) return null;
    return TrackPoint(lat: lat, lng: lng, t: t);
  }

  factory TrackPoint.fromMap(Map<String, dynamic> m) {
    final point = tryFromMap(m);
    if (point == null) throw const FormatException('Invalid history track point');
    return point;
  }
}

/// A stop of at least ~10 minutes. [placeId] is set when it happened at a saved place.
class Visit {
  Visit({
    this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.arrivedAt,
    this.leftAt,
  });

  final String? placeId;
  final String name;
  final double lat;
  final double lng;
  final int arrivedAt; // epoch ms
  int? leftAt; // null while still there

  Map<String, dynamic> toMap() => {
        if (placeId != null) 'placeId': placeId,
        'name': name,
        'lat': lat,
        'lng': lng,
        'arrivedAt': arrivedAt,
        'leftAt': leftAt,
      };

  static Visit? tryFromMap(Map<String, dynamic> m) {
    final rawPlaceId = m['placeId'];
    final rawName = m['name'];
    final rawLat = m['lat'];
    final rawLng = m['lng'];
    final arrivedAt = _safeInt(m['arrivedAt']);
    final rawLeftAt = m['leftAt'];
    final leftAt = rawLeftAt == null ? null : _safeInt(rawLeftAt);

    if (rawPlaceId != null && rawPlaceId is! String) return null;
    if (rawName != null && rawName is! String) return null;
    if (rawLat is! num || rawLng is! num || arrivedAt == null) return null;
    if (rawLeftAt != null && leftAt == null) return null;

    final lat = rawLat.toDouble();
    final lng = rawLng.toDouble();
    if (!_validCoordinates(lat, lng)) return null;
    if (leftAt != null && leftAt < arrivedAt) return null;

    return Visit(
      placeId: rawPlaceId as String?,
      name: rawName as String? ?? 'Unknown place',
      lat: lat,
      lng: lng,
      arrivedAt: arrivedAt,
      leftAt: leftAt,
    );
  }

  factory Visit.fromMap(Map<String, dynamic> m) {
    final visit = tryFromMap(m);
    if (visit == null) throw const FormatException('Invalid history visit');
    return visit;
  }
}

/// One member's history for one local calendar day (stored as a single compact document).
class DayTrack {
  DayTrack({
    required this.day,
    required this.tzOffsetMin,
    List<TrackPoint>? route,
    List<Visit>? visits,
    this.lastSeen = 0,
    this.updatedAt,
  })  : route = route ?? [],
        visits = visits ?? [];

  final String day; // yyyymmdd in the owner's local time
  final int tzOffsetMin;
  final List<TrackPoint> route;
  final List<Visit> visits;
  int lastSeen; // epoch ms of the last accepted fix
  final DateTime? updatedAt;

  Map<String, dynamic> toMap(String uid) => {
        'uid': uid,
        'day': day,
        'tzOffsetMin': tzOffsetMin,
        'visits': [for (final v in visits) v.toMap()],
        'route': [for (final p in route) p.toMap()],
        'lastSeen': lastSeen,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory DayTrack.fromMap(Map<String, dynamic> m) {
    final route = <TrackPoint>[];
    final rawRoute = m['route'];
    if (rawRoute is List) {
      for (final item in rawRoute) {
        final data = _stringKeyedMap(item);
        if (data == null) continue;
        final point = TrackPoint.tryFromMap(data);
        if (point != null) route.add(point);
      }
    }

    final visits = <Visit>[];
    final rawVisits = m['visits'];
    if (rawVisits is List) {
      for (final item in rawVisits) {
        final data = _stringKeyedMap(item);
        if (data == null) continue;
        final visit = Visit.tryFromMap(data);
        if (visit != null) visits.add(visit);
      }
    }

    final rawDay = m['day'];
    final rawUpdatedAt = m['updatedAt'];
    return DayTrack(
      day: rawDay is String ? rawDay : '',
      tzOffsetMin: _safeTimezoneOffset(m['tzOffsetMin']),
      route: route,
      visits: visits,
      lastSeen: _safeInt(m['lastSeen']) ?? 0,
      updatedAt: rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null,
    );
  }
}

/// yyyymmdd for a moment in the device's local time.
String dayKey(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}${two(l.month)}${two(l.day)}';
}

DateTime parseDayKey(String key) =>
    DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(4, 6)), int.parse(key.substring(6, 8)));

/// Formats an epoch-ms time in the *owner's* clock (UTC + their offset), e.g. "9:00 AM".
String formatClock(int epochMs, int tzOffsetMin) {
  final t = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).add(Duration(minutes: tzOffsetMin));
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
