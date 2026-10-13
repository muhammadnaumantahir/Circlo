import 'package:cloud_firestore/cloud_firestore.dart';

const int kMinRadiusM = 100;
const int kMaxRadiusM = 1000;
const int kDefaultRadiusM = 150;
const int kMaxPlacesPerCircle = 20; // enforced in the app only (rules cannot count)

class Place {
  const Place({
    required this.id,
    required this.circleId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.createdBy,
  });

  final String id;
  final String circleId;
  final String name;
  final double lat;
  final double lng;
  final double radiusM;
  final String createdBy;

  factory Place.fromMap(String circleId, String id, Map<String, dynamic> d) => Place(
        id: id,
        circleId: circleId,
        name: (d['name'] as String?) ?? '',
        lat: (d['lat'] as num).toDouble(),
        lng: (d['lng'] as num).toDouble(),
        radiusM: (d['radiusM'] as num).toDouble(),
        createdBy: (d['createdBy'] as String?) ?? '',
      );
}

/// The signed-in user's alert preferences for one place (in-app feed only; remote push deferred).
class PlaceSubscription {
  const PlaceSubscription({
    required this.circleId,
    required this.placeId,
    required this.arrive,
    required this.leave,
    required this.allMembers,
    required this.memberUids,
  });

  final String circleId;
  final String placeId;
  final bool arrive;
  final bool leave;
  final bool allMembers;
  final List<String> memberUids;

  bool get enabled => arrive || leave;

  bool wants(String type, String memberUid) {
    if (type == 'arrive' && !arrive) return false;
    if (type == 'leave' && !leave) return false;
    return allMembers || memberUids.contains(memberUid);
  }

  factory PlaceSubscription.fromMap(String circleId, Map<String, dynamic> d) =>
      PlaceSubscription(
        circleId: circleId,
        placeId: (d['placeId'] as String?) ?? '',
        arrive: d['arrive'] == true,
        leave: d['leave'] == true,
        allMembers: d['allMembers'] != false,
        memberUids: [for (final u in (d['memberUids'] as List? ?? const [])) u.toString()],
      );
}

class PlaceEvent {
  const PlaceEvent({
    required this.id,
    required this.circleId,
    required this.placeId,
    required this.placeName,
    required this.memberUid,
    required this.memberName,
    required this.type,
    required this.visitId,
    required this.occurredAt,
  });

  final String id;
  final String circleId;
  final String placeId;
  final String placeName;
  final String memberUid;
  final String memberName;
  final String type; // 'arrive' | 'leave'
  final String visitId;
  final DateTime? occurredAt;

  bool get isArrival => type == 'arrive';

  factory PlaceEvent.fromMap(String circleId, String id, Map<String, dynamic> d) =>
      PlaceEvent(
        id: id,
        circleId: circleId,
        placeId: (d['placeId'] as String?) ?? '',
        placeName: (d['placeName'] as String?) ?? '',
        memberUid: (d['memberUid'] as String?) ?? '',
        memberName: (d['memberName'] as String?) ?? 'Someone',
        type: (d['type'] as String?) ?? 'arrive',
        visitId: (d['visitId'] as String?) ?? '',
        occurredAt: (d['occurredAt'] as Timestamp?)?.toDate(),
      );
}

/// One line in the in-app notification feed.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.circleName,
    required this.text,
    required this.at,
    required this.isArrival,
  });

  final String id;
  final String circleName;
  final String text;
  final DateTime at;
  final bool isArrival;
}
