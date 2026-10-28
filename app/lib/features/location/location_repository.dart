import 'package:cloud_firestore/cloud_firestore.dart';

import '../circles/activity.dart';
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
                MyMembership.fromMap(d.reference.parent.parent!.id, d.data()),
          ]);

  Stream<Map<String, MemberLocation>> watchLocations(String circleId) => _db
      .collection('circles')
      .doc(circleId)
      .collection('locations')
      .where('sharing', isEqualTo: true)
      .snapshots()
      .map((snap) {
            final locations = <String, MemberLocation>{};
            for (final d in snap.docs) {
              final location = MemberLocation.tryFromMap(d.id, d.data());
              if (location != null) locations[d.id] = location;
            }
            return locations;
          });

  /// Turns sharing on/off for one circle. Turning off also deletes the location document
  /// in the same atomic batch, so the circle stops seeing it immediately.
  Future<void> setCircleSharing({
    required String uid,
    required String circleId,
    required bool enabled,
  }) async {
    final name = await _myName(circleId, uid);
    final batch = _db.batch();
    batch.update(_member(circleId, uid), {
      'sharesLocation': enabled,
      'paused': false,
      'pausedUntil': FieldValue.delete(),
      if (!enabled) 'historyShared': false, // history sharing never outlives location sharing
    });
    if (name != null) {
      batch.set(
        _db.collection('circles').doc(circleId).collection('activity').doc(),
        activityDoc(
          type: enabled ? ActivityType.sharingStarted : ActivityType.sharingStopped,
          actorUid: uid,
          actorName: name,
        ),
      );
    }
    if (!enabled) batch.delete(_location(circleId, uid));
    return batch.commit();
  }

  Future<String?> _myName(String circleId, String uid) async =>
      (await _member(circleId, uid).get()).data()?['displayName'] as String?;

  /// Pause/resume in all given circles (those where sharing is on). Pausing removes the locations.
  /// [until] makes the pause timed: the app resumes sharing automatically once it has passed.
  Future<void> setPausedForCircles({
    required String uid,
    required Iterable<String> circleIds,
    required bool paused,
    DateTime? until,
  }) {
    final batch = _db.batch();
    for (final id in circleIds) {
      batch.update(_member(id, uid), {
        'paused': paused,
        'pausedUntil': (paused && until != null) ? Timestamp.fromDate(until) : FieldValue.delete(),
      });
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
    if (!isValidLocationSample(lat: lat, lng: lng, accuracy: accuracy)) {
      throw ArgumentError('Cannot publish an invalid location sample.');
    }
    final batch = _db.batch();
    for (final id in circleIds) {
      batch.set(_location(id, uid), {
        'uid': uid,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'sharing': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  /// Switches sharing off in every given circle and removes the locations (used on log-out).
  Future<void> stopSharing({required String uid, required Iterable<String> circleIds}) async {
    final batch = _db.batch();
    for (final id in circleIds) {
      final name = await _myName(id, uid);
      batch.update(_member(id, uid), {
        'sharesLocation': false,
        'paused': false,
        'pausedUntil': FieldValue.delete(),
        'historyShared': false,
      });
      batch.delete(_location(id, uid));
      if (name != null) {
        batch.set(
          _db.collection('circles').doc(id).collection('activity').doc(),
          activityDoc(type: ActivityType.sharingStopped, actorUid: uid, actorName: name),
        );
      }
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
