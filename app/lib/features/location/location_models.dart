import 'package:cloud_firestore/cloud_firestore.dart';

/// Validates a GPS sample before it is written or displayed.
bool isValidLocationSample({required double lat, required double lng, required double accuracy}) =>
    lat.isFinite && lng.isFinite && accuracy.isFinite &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && accuracy >= 0;

/// Latest shared position of one member inside one circle.
class MemberLocation {
  const MemberLocation({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.updatedAt,
  });

  final String uid;
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime? updatedAt; // null while the server timestamp is still pending

  /// Returns null for malformed or out-of-range coordinates instead of letting
  /// one bad Firestore document break the entire live-location stream.
  static MemberLocation? tryFromMap(String uid, Map<String, dynamic> data) {
    final rawLat = data['lat'];
    final rawLng = data['lng'];
    final rawAccuracy = data['accuracy'];
    if (rawLat is! num || rawLng is! num) return null;

    final lat = rawLat.toDouble();
    final lng = rawLng.toDouble();
    final accuracy = rawAccuracy is num ? rawAccuracy.toDouble() : 0.0;
    if (!lat.isFinite || !lng.isFinite || !accuracy.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180 || accuracy < 0) {
      return null;
    }

    final rawUpdatedAt = data['updatedAt'];
    return MemberLocation(
      uid: uid,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      updatedAt: rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null,
    );
  }

  factory MemberLocation.fromMap(String uid, Map<String, dynamic> data) {
    final parsed = tryFromMap(uid, data);
    if (parsed == null) {
      throw FormatException('Invalid location document for member $uid');
    }
    return parsed;
  }
}

/// The signed-in user's own sharing switches for one circle.
class MyMembership {
  const MyMembership({
    required this.circleId,
    required this.sharesLocation,
    required this.paused,
    this.historyShared = false,
    this.pausedUntil,
  });

  final String circleId;
  final bool sharesLocation;
  final bool paused;
  final bool historyShared;
  final DateTime? pausedUntil; // timed pause: resume automatically after this moment

  /// Builds membership state without trusting the Firestore field types.
  factory MyMembership.fromMap(String circleId, Map<String, dynamic> data) {
    final rawPausedUntil = data['pausedUntil'];
    return MyMembership(
      circleId: circleId,
      sharesLocation: data['sharesLocation'] == true,
      paused: data['paused'] == true,
      historyShared: data['historyShared'] == true,
      // A malformed optional timestamp should not terminate the whole memberships stream.
      pausedUntil: rawPausedUntil is Timestamp ? rawPausedUntil.toDate() : null,
    );
  }

  /// Location is actually being published to this circle.
  bool get isActive => sharesLocation && !paused;
}
