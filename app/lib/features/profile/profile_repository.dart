import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<UserProfile?> watch(String uid) => _doc(uid).snapshots().map(
      (s) => s.exists ? UserProfile.fromMap(uid, s.data()!) : null);

  Future<void> create({
    required String uid,
    required String displayName,
    required int birthYear,
    String? phone,
  }) {
    final cleanPhone = phone?.trim() ?? '';
    return _doc(uid).set({
      'displayName': displayName.trim(),
      'birthYear': birthYear,
      if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setHistoryPrefs({
    required String uid,
    required bool keepHistory,
    required int retentionDays,
  }) =>
      _doc(uid).update({
        'keepHistory': keepHistory,
        'retentionDays': retentionDays,
        if (!keepHistory) 'placeSuggestionsEnabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setPlaceSuggestionsEnabled({
    required String uid,
    required bool enabled,
  }) {
    return _doc(uid).update({
      'placeSuggestionsEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setNotificationPrefs({
    required String uid,
    required List<String> off,
    required List<String> muted,
  }) =>
      _doc(uid).update({
        'notifOff': off,
        'notifMuted': muted,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> markNotificationsSeen(String uid) => _doc(uid).update({
        'notifSeenAt': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> update({
    required String uid,
    required String displayName,
    String? phone,
  }) async {
    final cleanPhone = phone?.trim() ?? '';

    // Find only this user's memberships, then read only their own contact document in each circle.
    // Shared contacts are updated in the same batch as the private phone value to avoid stale copies.
    final memberships = await _db.collectionGroup('members').where('uid', isEqualTo: uid).get();
    final sharedContactDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final membership in memberships.docs) {
      final circleRef = membership.reference.parent.parent;
      if (circleRef == null) continue;
      try {
        final shared = await circleRef.collection('sharedContacts').doc(uid).get();
        if (shared.exists && shared.data()?['sharePhone'] == true) {
          sharedContactDocs.add(shared);
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    // The profile itself plus every shared copy must fit in one atomic Firestore batch.
    if (sharedContactDocs.length >= 499) {
      throw StateError('Too many shared contacts to update safely. Turn sharing off in some circles first.');
    }
    final batch = _db.batch();
    batch.update(_doc(uid), {
      'displayName': displayName.trim(),
      'phone': cleanPhone.isEmpty ? FieldValue.delete() : cleanPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final contact in sharedContactDocs) {
      if (cleanPhone.isEmpty) {
        batch.delete(contact.reference);
      } else {
        batch.update(contact.reference, {
          'phone': cleanPhone,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }
}
