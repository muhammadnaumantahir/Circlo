import 'package:cloud_firestore/cloud_firestore.dart';

import 'location_models.dart';

/// Reads/writes circle-scoped location data. Authorization lives in firestore.rules.
class LocationRepository {
  LocationRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _member(String circleId, String uid) =>
      _db.collection('circles').doc(circleId).collection('members').doc(uid);

  DocumentReference<Map<String, dynamic>> _location(String circleId, String uid) =>
      _db.collection('circles').doc(circleId).collection('locations').doc(uid);

  /// The user's own sharing switches in every circle they belong to.
  Stream<List<MyMembership>> watchMyMemberships(String uid) => _db
      .collectionGroup('members')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((snap) => [
            for (final d in snap.docs)
              if (d.reference.parent.parent != null)
                MyMembership(
                  circleId: d.reference.parent.parent!.id,
                  sharesLocation: d.data()['sharesLocation'] == true,
                  paused: d.data()['paused'] == true,
                ),
          ]);

  Stream<Map<String, MemberLocation>> watchLocations(String circleId) => _db
      .collection('circles')
      .doc(circleId)
      .collection('locations')
      .snapshots()
      .map((snap) => {
            for (final d in snap.docs) d.id: MemberLocation.fromMap(d.id, d.data()),
          });

  /// Turns sharing on/off for one circle. Turning off also deletes the location document
  /// in the same atomic batch, so the circle stops seeing it immediately.
  Future<void> setCircleSharing({
    required String uid,
    required String circleId,
    required bool enabled,
  }) {
    final batch = _db.batch();
    batch.update(_member(circleId, uid), {'sharesLocation': enabled, 'paused': false});
    if (!enabled) batch.delete(_location(circleId, uid));
    return batch.commit();
  }

  /// Pause/resume in all given circles (those where sharing is on). Pausing removes the locations.
  Future<void> setPausedForCircles({
    required String uid,
    required Iterable<String> circleIds,
    required bool paused,
  }) {
    final batch = _db.batch();
    for (final id in circleIds) {
      batch.update(_member(id, uid), {'paused': paused});
      if (paused) batch.delete(_location(id, uid));
    }
    return batch.commit();
  }

  /// Publishes the same position to every circle that is currently sharing.
  Future<void> publish({
    required String uid,
    required Iterable<String> circleIds,
    required double lat,
    required double lng,
    required double accuracy,
  }) {
    final batch = _db.batch();
    for (final id in circleIds) {
      batch.set(_location(id, uid), {
        'uid': uid,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy < 0 ? 0 : accuracy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  /// Switches sharing off in every given circle and removes the locations (used on log-out).
  Future<void> stopSharing({required String uid, required Iterable<String> circleIds}) {
    final batch = _db.batch();
    for (final id in circleIds) {
      batch.update(_member(id, uid), {'sharesLocation': false, 'paused': false});
      batch.delete(_location(id, uid));
    }
    return batch.commit();
  }

  /// Best-effort removal of own location documents (used on log-out / app stop).
  Future<void> clearMyLocations({required String uid, required Iterable<String> circleIds}) {
    final batch = _db.batch();
    for (final id in circleIds) {
      batch.delete(_location(id, uid));
    }
    return batch.commit();
  }
}
