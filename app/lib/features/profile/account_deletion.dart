import 'package:cloud_firestore/cloud_firestore.dart';

import '../circles/circles_repository.dart';
import '../history/history_repository.dart';

/// A circle the user owns that still has other members (must be transferred or deleted first).
class OwnedCircle {
  const OwnedCircle({required this.id, required this.name, required this.memberCount});
  final String id;
  final String name;
  final int memberCount;
}

/// Best-effort, client-side account deletion (there is no server to guarantee completeness).
/// It removes what the app can reach: memberships, shared location, alerts, events, history,
/// pending requests and the profile; the Firebase sign-in is removed last. Data that other
/// people's circles hold about you and that you cannot list (for example orphaned copies
/// after a removed membership) may remain; see docs/risks.md.
class AccountDeletionService {
  AccountDeletionService({
    required FirebaseFirestore db,
    required this.circles,
    required this.history,
  }) : _db = db;

  final FirebaseFirestore _db;
  final CirclesRepository circles;
  final HistoryRepository history;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _myMemberships(String uid) async =>
      (await _db.collectionGroup('members').where('uid', isEqualTo: uid).get()).docs;

  /// Owned circles that block deletion because other people are still in them.
  Future<List<OwnedCircle>> blockingCircles(String uid) async {
    final out = <OwnedCircle>[];
    for (final m in await _myMemberships(uid)) {
      if (m.data()['role'] != 'owner') continue;
      final circleRef = m.reference.parent.parent;
      if (circleRef == null) continue;
      final members = await circleRef.collection('members').get();
      if (members.size > 1) {
        final c = await circleRef.get();
        out.add(OwnedCircle(id: circleRef.id, name: (c.data()?['name'] as String?) ?? 'Circle', memberCount: members.size));
      }
    }
    return out;
  }

  /// Runs every data step; returns normally only when all of them succeeded.
  /// The caller deletes the Firebase Auth user afterwards.
  Future<void> deleteAllData(String uid) async {
    final days = <String>[];
    for (;;) {
      final batchDays = await history.myDays(uid, limit: 200);
      if (batchDays.isEmpty) break;
      days.addAll(batchDays);
      await history.deleteDays(uid: uid, days: batchDays, circleIds: const []);
      if (batchDays.length < 200) break;
    }

    for (final m in await _myMemberships(uid)) {
      final circleRef = m.reference.parent.parent;
      if (circleRef == null) continue;
      final circleId = circleRef.id;
      if (m.data()['role'] == 'owner') {
        // Only reachable when we are the sole member (blockingCircles() was empty).
        await circles.deleteCircle(circleId: circleId, ownerUid: uid);
        continue;
      }
      final batch = _db.batch();
      // own alert preferences (ids are derived from the places we can list)
      final places = await circleRef.collection('places').get();
      for (final p in places.docs) {
        batch.delete(circleRef.collection('placeSubscriptions').doc('${uid}_${p.id}'));
      }
      // own events (queryable by ourselves)
      final events = await circleRef.collection('placeEvents').where('memberUid', isEqualTo: uid).get();
      for (final e in events.docs) {
        batch.delete(e.reference);
      }
      // own history copies for the days we know about
      for (final day in days) {
        batch.delete(circleRef.collection('history').doc('${uid}_$day'));
      }
      batch.delete(circleRef.collection('locations').doc(uid));
      batch.delete(m.reference);
      await batch.commit();
    }

    final requests = await _db.collectionGroup('joinRequests').where('uid', isEqualTo: uid).get();
    for (final r in requests.docs) {
      await r.reference.delete();
    }
    await _db.collection('users').doc(uid).delete();
  }
}
