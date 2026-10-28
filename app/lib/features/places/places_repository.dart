import 'package:cloud_firestore/cloud_firestore.dart';

import 'place_models.dart';

/// Places, per-user alert preferences and arrival/departure events (all circle-scoped).
/// Authorization is enforced by firebase/firestore.rules.
class PlacesRepository {
  PlacesRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _circle(String id) => _db.collection('circles').doc(id);

  Stream<List<Place>> watchPlaces(String circleId) => _circle(circleId)
      .collection('places')
      .snapshots()
      .map((s) {
        final list = [for (final d in s.docs) Place.fromMap(circleId, d.id, d.data())];
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Creates the place and the creator's alert preferences atomically.
  Future<String> createPlace({
    required String circleId,
    required String uid,
    required String name,
    required double lat,
    required double lng,
    required double radiusM,
    required PlaceSubscription subscription,
  }) async {
    final ref = _circle(circleId).collection('places').doc();
    final batch = _db.batch();
    batch.set(ref, {
      'name': name.trim(),
      'lat': lat,
      'lng': lng,
      'radiusM': radiusM,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_subRef(circleId, uid, ref.id), _subMap(uid, ref.id, subscription));
    await batch.commit();
    return ref.id;
  }

  Future<void> updatePlace({
    required String circleId,
    required String placeId,
    required String name,
    required double lat,
    required double lng,
    required double radiusM,
  }) =>
      _circle(circleId).collection('places').doc(placeId).update({
        'name': name.trim(),
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
      });

  /// Deletes the place and the caller's own preferences (other members' preference documents
  /// become harmless orphans: there is no server to clean them).
  Future<void> deletePlace({
    required String circleId,
    required String placeId,
    required String uid,
  }) {
    final batch = _db.batch();
    batch.delete(_circle(circleId).collection('places').doc(placeId));
    batch.delete(_subRef(circleId, uid, placeId));
    return batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _subRef(String circleId, String uid, String placeId) =>
      _circle(circleId).collection('placeSubscriptions').doc('${uid}_$placeId');

  Map<String, dynamic> _subMap(String uid, String placeId, PlaceSubscription s) => {
        'subscriberUid': uid,
        'placeId': placeId,
        'arrive': s.arrive,
        'leave': s.leave,
        'allMembers': s.allMembers,
        'memberUids': s.memberUids,
        'paused': s.paused,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Future<void> saveSubscription({
    required String circleId,
    required String uid,
    required String placeId,
    required PlaceSubscription subscription,
  }) =>
      _subRef(circleId, uid, placeId).set(_subMap(uid, placeId, subscription));

  Future<PlaceSubscription?> getSubscription(String circleId, String uid, String placeId) async {
    final s = await _subRef(circleId, uid, placeId).get();
    final d = s.data();
    return (s.exists && d != null) ? PlaceSubscription.fromMap(circleId, d) : null;
  }

  /// All of the user's alert preferences across circles (collection-group query on own docs).
  Stream<List<PlaceSubscription>> watchMySubscriptions(String uid) => _db
      .collectionGroup('placeSubscriptions')
      .where('subscriberUid', isEqualTo: uid)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              if (d.reference.parent.parent != null)
                PlaceSubscription.fromMap(d.reference.parent.parent!.id, d.data()),
          ]);

  Stream<List<PlaceEvent>> watchRecentEvents(String circleId, {int limit = 50}) => _circle(circleId)
      .collection('placeEvents')
      .orderBy('occurredAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) PlaceEvent.fromMap(circleId, d.id, d.data())]);

  /// The user's own latest events, newest first (used to restore "inside" state after a restart).
  Future<List<PlaceEvent>> myLatestEvents(String circleId, String uid, {int limit = 50}) async {
    final s = await _circle(circleId)
        .collection('placeEvents')
        .where('memberUid', isEqualTo: uid)
        .orderBy('occurredAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in s.docs) PlaceEvent.fromMap(circleId, d.id, d.data())];
  }

  /// The caller's display name as stored on their membership (events must carry exactly this).
  Future<String?> myMemberName(String circleId, String uid) async {
    final s = await _circle(circleId).collection('members').doc(uid).get();
    return s.data()?['displayName'] as String?;
  }

  /// Idempotent: the document id is derived from (member, place, visit, type), so a retry of an
  /// already-written event is rejected by the rules (no updates) and can be ignored.
  Future<void> publishEvent({
    required String circleId,
    required String uid,
    required String memberName,
    required Place place,
    required String type,
    required String visitId,
  }) =>
      _circle(circleId).collection('placeEvents').doc('${uid}_${place.id}_${visitId}_$type').set({
        'placeId': place.id,
        'placeName': place.name,
        'memberUid': uid,
        'memberName': memberName,
        'type': type,
        'visitId': visitId,
        'occurredAt': FieldValue.serverTimestamp(),
      });
}
