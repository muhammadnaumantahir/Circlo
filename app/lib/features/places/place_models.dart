import 'package:cloud_firestore/cloud_firestore.dart';

const int kMinRadiusM = 100;
const int kMaxRadiusM = 1000;
const int kDefaultRadiusM = 150;
const int kMaxPlacesPerCircle = 20; // enforced in the app only (rules cannot count)

bool _validPlaceCoordinate(double lat, double lng) =>
    lat.isFinite && lng.isFinite && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

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

  /// Parses a saved place only when its coordinates and radius are safe to use.
  static Place? tryFromMap(String circleId, String id, Map<String, dynamic> d) {
    final rawLat = d['lat'];
    final rawLng = d['lng'];
    final rawRadius = d['radiusM'];
    if (rawLat is! num || rawLng is! num || rawRadius is! num) return null;

    final lat = rawLat.toDouble();
    final lng = rawLng.toDouble();
    final radiusM = rawRadius.toDouble();
    final name = (d['name'] as String?)?.trim() ?? '';
    if (name.isEmpty || !_validPlaceCoordinate(lat, lng)) return null;
    if (!radiusM.isFinite || radiusM < kMinRadiusM || radiusM > kMaxRadiusM) return null;

    return Place(
      id: id,
      circleId: circleId,
      name: name,
      lat: lat,
      lng: lng,
      radiusM: radiusM,
      createdBy: (d['createdBy'] as String?) ?? '',
    );
  }

  factory Place.fromMap(String circleId, String id, Map<String, dynamic> d) {
    final place = tryFromMap(circleId, id, d);
    if (place == null) throw FormatException('Invalid saved place document $id');
    return place;
  }
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
    this.paused = false,
  });

  final String circleId;
  final String placeId;
  final bool arrive;
  final bool leave;
  final bool allMembers;
  final List<String> memberUids;
  /// Temporarily suppresses both alert types without losing their configured choices.
  final bool paused;

  bool get enabled => !paused && (arrive || leave);

  bool wants(String type, String memberUid) {
    if (paused) return false;
    if (type == 'arrive' && !arrive) return false;
    if (type == 'leave' && !leave) return false;
    return allMembers || memberUids.contains(memberUid);
  }

  /// Parses a subscription defensively so one malformed Firestore document cannot break
  /// the collection-group stream for every other subscription.
  static PlaceSubscription? tryFromMap(String circleId, Map<String, dynamic> d) {
    final rawPlaceId = d['placeId'];
    if (rawPlaceId is! String || rawPlaceId.trim().isEmpty) return null;

    final rawMembers = d['memberUids'];
    if (rawMembers != null && rawMembers is! List) return null;
    final members = <String>[];
    for (final uid in (rawMembers as List? ?? const [])) {
      if (uid is! String || uid.trim().isEmpty) return null;
      members.add(uid);
    }

    return PlaceSubscription(
      circleId: circleId,
      placeId: rawPlaceId,
      arrive: d['arrive'] == true,
      leave: d['leave'] == true,
      allMembers: d['allMembers'] != false,
      memberUids: members,
      // Older subscription documents did not have this field.
      paused: d['paused'] == true,
    );
  }

  factory PlaceSubscription.fromMap(String circleId, Map<String, dynamic> d) {
    final subscription = tryFromMap(circleId, d);
    if (subscription == null) {
      throw const FormatException('Invalid place subscription document');
    }
    return subscription;
  }
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

/// Notification categories the user can switch off (FR-081).
enum FeedKind { place, membership, sharing, unavailable, requests, checkIns }

String feedKindName(FeedKind k) => k.name;

String feedKindLabel(FeedKind k) {
  switch (k) {
    case FeedKind.place:
      return 'Arrivals and departures at places';
    case FeedKind.membership:
      return 'Members joining, leaving or removed';
    case FeedKind.sharing:
      return 'Someone starts or stops sharing';
    case FeedKind.unavailable:
      return 'Someone\'s location becomes unavailable';
    case FeedKind.requests:
      return 'Join requests for circles I own';
    case FeedKind.checkIns:
      return 'Manual member check-ins';
  }
}

/// One line in the in-app notification feed.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.kind,
    required this.text,
    required this.at,
    this.isArrival = false,
  });

  final String id;
  final String circleId;
  final String circleName;
  final FeedKind kind;
  final String text;
  final DateTime at;
  final bool isArrival; // only meaningful for FeedKind.place
}
