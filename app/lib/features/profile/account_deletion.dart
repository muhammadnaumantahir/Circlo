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

  static const int _deleteBatchSize = 400;

  /// Deletes bulk data in safe chunks. Keep security-sensitive revocation writes in their own
  /// small atomic batch, because Firestore Rules require location + membership deletion together.
  Future<void> _deleteReferencesInBatches(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    for (var i = 0; i < refs.length; i += _deleteBatchSize) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(_deleteBatchSize)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

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
    // Read the full day-key set first. Do not delete the private master keys until all reachable
    // circle copies have been cleaned up; otherwise a failure and retry would lose the day list.
    final days = await history.allMyDays(uid);

    for (final m in await _myMemberships(uid)) {
      final circleRef = m.reference.parent.parent;
      if (circleRef == null) continue;
      if (m.data()['role'] == 'owner') {
        // Only reachable when we are the sole member (blockingCircles() is checked by the UI).
        // Remove this user's known history copies before circle deletion; the circle repository
        // also cleans its normal retention window and other reachable subcollection documents.
        await _deleteReferencesInBatches([
          for (final day in days) circleRef.collection('history').doc('${uid}_$day'),
        ]);
        await circles.deleteCircle(circleId: circleRef.id, ownerUid: uid);
        continue;
      }

      final cleanupRefs = <DocumentReference<Map<String, dynamic>>>[];
      // Own alert preferences (IDs are derived from places we can list).
      final places = await circleRef.collection('places').get();
      for (final p in places.docs) {
        cleanupRefs.add(circleRef.collection('placeSubscriptions').doc('${uid}_${p.id}'));
      }
      // Own events (queryable by ourselves). This may exceed one Firestore batch.
      final events = await circleRef.collection('placeEvents').where('memberUid', isEqualTo: uid).get();
      cleanupRefs.addAll(events.docs.map((e) => e.reference));
      // Own history copies for every day recorded in the private master list.
      for (final day in days) {
        cleanupRefs.add(circleRef.collection('history').doc('${uid}_$day'));
      }
      await _deleteReferencesInBatches(cleanupRefs);

      // Revoke access in one small atomic operation: Firestore Rules require that a member
      // cannot be removed while their live-location projection remains.
      final revoke = _db.batch();
      revoke.delete(circleRef.collection('locations').doc(uid));
      revoke.delete(circleRef.collection('sharedContacts').doc(uid));
      revoke.delete(m.reference);
      await revoke.commit();
    }

    // This happens only after reachable circle copies are handled, preserving retryability.
    await history.deleteDays(uid: uid, days: days, circleIds: const []);

    final requests = await _db.collectionGroup('joinRequests').where('uid', isEqualTo: uid).get();
    await _deleteReferencesInBatches([for (final r in requests.docs) r.reference]);
    await _db.collection('users').doc(uid).delete();
  }
}
