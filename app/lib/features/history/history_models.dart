import 'package:cloud_firestore/cloud_firestore.dart';

class TrackPoint {
  const TrackPoint({required this.lat, required this.lng, required this.t});
  final double lat;
  final double lng;
  final int t; // epoch milliseconds

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 't': t};

  factory TrackPoint.fromMap(Map<String, dynamic> m) => TrackPoint(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        t: (m['t'] as num).toInt(),
      );
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

  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
        placeId: m['placeId'] as String?,
        name: (m['name'] as String?) ?? 'Unknown place',
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        arrivedAt: (m['arrivedAt'] as num).toInt(),
        leftAt: (m['leftAt'] as num?)?.toInt(),
      );
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

  factory DayTrack.fromMap(Map<String, dynamic> m) => DayTrack(
        day: (m['day'] as String?) ?? '',
        tzOffsetMin: (m['tzOffsetMin'] as num?)?.toInt() ?? 0,
        route: [for (final p in (m['route'] as List? ?? const [])) TrackPoint.fromMap(Map<String, dynamic>.from(p as Map))],
        visits: [for (final v in (m['visits'] as List? ?? const [])) Visit.fromMap(Map<String, dynamic>.from(v as Map))],
        lastSeen: (m['lastSeen'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );
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
