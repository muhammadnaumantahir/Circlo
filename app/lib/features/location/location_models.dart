import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory MemberLocation.fromMap(String uid, Map<String, dynamic> data) =>
      MemberLocation(
        uid: uid,
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0,
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
}

/// The signed-in user's own sharing switches for one circle.
class MyMembership {
  const MyMembership({
    required this.circleId,
    required this.sharesLocation,
    required this.paused,
  });

  final String circleId;
  final bool sharesLocation;
  final bool paused;

  /// Location is actually being published to this circle.
  bool get isActive => sharesLocation && !paused;
}
