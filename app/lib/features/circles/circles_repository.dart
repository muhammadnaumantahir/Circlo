import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/join_code.dart';
import 'circle_models.dart';

/// All writes here are checked by firebase/firestore.rules; the app never trusts itself.
class CirclesRepository {
  CirclesRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _circles =>
      _db.collection('circles');
  CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('joinCodes');

  /// Circles the user belongs to, found through their own membership documents.
  Stream<List<Circle>> watchMyCircles(String uid) {
    return _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .asyncMap((snap) async {
      final circles = <Circle>[];
      for (final m in snap.docs) {
        final ref = m.reference.parent.parent;
        if (ref == null) continue;
        try {
          final c = await ref.get();
          if (c.exists) circles.add(Circle.fromMap(c.id, c.data()!));
        } on FirebaseException {
          continue; // no longer allowed to read this circle
        }
      }
      circles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return circles;
    });
  }

  Stream<Circle?> watchCircle(String circleId) => _circles
      .doc(circleId)
      .snapshots()
      .map((s) => s.exists ? Circle.fromMap(s.id, s.data()!) : null);

  Stream<List<Member>> watchMembers(String circleId) => _circles
      .doc(circleId)
      .collection('members')
      .snapshots()
      .map((s) {
        final members = s.docs.map((d) => Member.fromMap(d.id, d.data())).toList();
        members.sort((a, b) {
          if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
        return members;
      });

  /// Creates the circle, the owner's membership and the join code in one atomic batch.
  Future<String> createCircle({
    required String uid,
    required String displayName,
    required String name,
  }) async {
    FirebaseException? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = generateJoinCode();
      final circleRef = _circles.doc();
      final batch = _db.batch();
      batch.set(circleRef, {
        'name': name.trim(),
        'ownerUid': uid,
        'requiresApproval': false,
        'joinCode': code,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(circleRef.collection('members').doc(uid), {
        'uid': uid,
        'role': 'owner',
        'displayName': displayName,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_codes.doc(code), {
        'circleId': circleRef.id,
        'createdBy': uid,
        'revoked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      try {
        await batch.commit();
        return circleRef.id;
      } on FirebaseException catch (e) {
        // A permission error here can mean the random code already exists; retry with a new one.
        if (e.code != 'permission-denied') rethrow;
        last = e;
      }
    }
    throw last!;
  }

  /// Joins a circle by code. Returns the circle id.
  Future<String> joinCircle({
    required String uid,
    required String displayName,
    required String rawCode,
  }) async {
    final code = normalizeJoinCode(rawCode);
    if (!isValidJoinCode(code)) {
      throw const JoinFailure(JoinFailureKind.invalid);
    }
    final codeSnap = await _codes.doc(code).get();
    final data = codeSnap.data();
    if (!codeSnap.exists || data == null || data['revoked'] == true) {
      throw const JoinFailure(JoinFailureKind.invalid);
    }
    final expires = data['expiresAt'];
    if (expires is Timestamp && expires.toDate().isBefore(DateTime.now())) {
      throw const JoinFailure(JoinFailureKind.invalid);
    }
    final circleId = data['circleId'] as String?;
    if (circleId == null) throw const JoinFailure(JoinFailureKind.invalid);

    final memberRef = _circles.doc(circleId).collection('members').doc(uid);
    if ((await memberRef.get()).exists) {
      throw const JoinFailure(JoinFailureKind.alreadyMember);
    }
    try {
      await memberRef.set({
        'uid': uid,
        'role': 'member',
        'displayName': displayName,
        'joinedAt': FieldValue.serverTimestamp(),
        'joinCode': code,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const JoinFailure(JoinFailureKind.invalid);
      }
      rethrow;
    }
    return circleId;
  }

  Future<void> leaveCircle({required String circleId, required String uid}) =>
      _circles.doc(circleId).collection('members').doc(uid).delete();

  /// Owner only (enforced by rules).
  Future<void> removeMember({required String circleId, required String memberUid}) =>
      _circles.doc(circleId).collection('members').doc(memberUid).delete();

  /// Owner only: revokes the current code and issues a new one atomically.
  Future<void> rotateJoinCode({
    required String circleId,
    required String oldCode,
    required String uid,
  }) {
    final newCode = generateJoinCode();
    final batch = _db.batch();
    batch.update(_codes.doc(oldCode), {'revoked': true});
    batch.set(_codes.doc(newCode), {
      'circleId': circleId,
      'createdBy': uid,
      'revoked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_circles.doc(circleId), {'joinCode': newCode});
    return batch.commit();
  }

  /// Keeps the display name shown to circle members in step with the profile.
  Future<void> syncDisplayName({required String uid, required String displayName}) async {
    final snap = await _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'displayName': displayName});
    }
    await batch.commit();
  }
}
