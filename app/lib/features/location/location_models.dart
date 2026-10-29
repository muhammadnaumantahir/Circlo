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
    this.batteryLevel,
    this.approximate = false,
  });

  final String uid;
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime? updatedAt; // null while the server timestamp is still pending
  /// Last battery percentage shared with this circle. Null when not opted in or unavailable.
  final int? batteryLevel;
  /// True when this is a coarse grid point, not the member's precise GPS coordinates.
  final bool approximate;

  /// Returns null for malformed or out-of-range coordinates instead of letting
  /// one bad Firestore document break the entire live-location stream.
  static MemberLocation? tryFromMap(String uid, Map<String, dynamic> data) {
    final rawLat = data['lat'];
    final rawLng = data['lng'];
    final rawAccuracy = data['accuracy'];
    if (rawLat is! num || rawLng is! num) return null;
    // Keep legacy documents without accuracy readable, but do not disguise a
    // present, malformed accuracy value as a perfect GPS fix.
    if (rawAccuracy != null && rawAccuracy is! num) return null;

    final lat = rawLat.toDouble();
    final lng = rawLng.toDouble();
    final accuracy = rawAccuracy is num ? rawAccuracy.toDouble() : 0.0;
    if (!lat.isFinite || !lng.isFinite || !accuracy.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180 || accuracy < 0) {
      return null;
    }

    final rawUpdatedAt = data['updatedAt'];
    final rawBatteryLevel = data['batteryLevel'];
    final rawApproximate = data['approximate'];
    if (rawApproximate != null && rawApproximate is! bool) return null;
    final batteryLevel = rawBatteryLevel is int && rawBatteryLevel >= 0 && rawBatteryLevel <= 100
        ? rawBatteryLevel
        : null;
    return MemberLocation(
      uid: uid,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      updatedAt: rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null,
      batteryLevel: batteryLevel,
      approximate: rawApproximate == true,
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
    this.shareBattery = false,
    this.bubbleUntil,
    this.pausedUntil,
  });

  final String circleId;
  final bool sharesLocation;
  final bool paused;
  final bool historyShared;
  final bool shareBattery; // independent per-circle consent; off by default
  /// Expiry of temporary coarse map sharing for this circle. Null means precise sharing.
  final DateTime? bubbleUntil;
  final DateTime? pausedUntil; // Timed pause: resume automatically after this moment.

  bool isApproximateAt(DateTime now) => bubbleUntil?.isAfter(now) ?? false;

  bool get isApproximate => isApproximateAt(DateTime.now());

  /// Builds membership state without trusting the Firestore field types.
  factory MyMembership.fromMap(String circleId, Map<String, dynamic> data) {
    final rawPausedUntil = data['pausedUntil'];
    final rawBubbleUntil = data['bubbleUntil'];
    return MyMembership(
      circleId: circleId,
      sharesLocation: data['sharesLocation'] == true,
      paused: data['paused'] == true,
      historyShared: data['historyShared'] == true,
      shareBattery: data['shareBattery'] == true,
      // A malformed optional timestamp fails closed: it does not enable approximate mode.
      bubbleUntil: rawBubbleUntil is Timestamp ? rawBubbleUntil.toDate() : null,
      // A malformed optional timestamp should not terminate the whole memberships stream.
      pausedUntil: rawPausedUntil is Timestamp ? rawPausedUntil.toDate() : null,
    );
  }

  /// Location is actually being published to this circle.
  bool get isActive => sharesLocation && !paused;
}
