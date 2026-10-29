import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/join_code.dart';
import '../history/history_models.dart';
import 'activity.dart';
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
        'sharesLocation': false, // sharing is always opt-in
        'paused': false,
        'historyShared': false,
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

  /// Joins a circle by code, or sends a join request when the circle requires approval.
  Future<JoinOutcome> joinCircle({
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

    final circle = _circles.doc(circleId);
    final memberRef = circle.collection('members').doc(uid);
    if ((await memberRef.get()).exists) {
      throw const JoinFailure(JoinFailureKind.alreadyMember);
    }
    final requestRef = circle.collection('joinRequests').doc(uid);
    try {
      if ((await requestRef.get()).exists) {
        return JoinOutcome(circleId: circleId, requested: true); // already asked
      }
    } on FirebaseException {
      // fall through: try to join normally
    }

    // 1) Open circle: join directly with the code.
    try {
      final batch = _db.batch();
      batch.set(memberRef, {
        'uid': uid,
        'role': 'member',
        'displayName': displayName,
        'joinedAt': FieldValue.serverTimestamp(),
        'joinCode': code,
        'sharesLocation': false, // sharing is always opt-in
        'paused': false,
        'historyShared': false,
      });
      batch.set(circle.collection('activity').doc(),
          activityDoc(type: ActivityType.joined, actorUid: uid, actorName: displayName));
      await batch.commit();
      return JoinOutcome(circleId: circleId, requested: false);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    // 2) Approval circle (we cannot read the circle to know): ask the owner instead.
    try {
      await requestRef.set({
        'uid': uid,
        'displayName': displayName,
        'joinCode': code,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return JoinOutcome(circleId: circleId, requested: true);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const JoinFailure(JoinFailureKind.invalid);
      }
      rethrow;
    }
  }

  /// The user's own join requests across circles.
  Stream<List<JoinRequest>> watchMyRequests(String uid) => _db
      .collectionGroup('joinRequests')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              if (d.reference.parent.parent != null)
                JoinRequest.fromMap(d.reference.parent.parent!.id, d.data()),
          ]);

  /// Once the owner approved, create the membership and remove the request (atomic).
  Future<void> completeApprovedJoin({required String uid, required String displayName, required JoinRequest request}) {
    final circle = _circles.doc(request.circleId);
    final batch = _db.batch();
    batch.set(circle.collection('members').doc(uid), {
      'uid': uid,
      'role': 'member',
      'displayName': displayName,
      'joinedAt': FieldValue.serverTimestamp(),
      'joinCode': request.joinCode,
      'sharesLocation': false,
      'paused': false,
      'historyShared': false,
    });
    batch.delete(circle.collection('joinRequests').doc(uid));
    batch.set(circle.collection('activity').doc(),
        activityDoc(type: ActivityType.joined, actorUid: uid, actorName: displayName));
    return batch.commit();
  }

  Future<void> cancelRequest({required String circleId, required String uid}) =>
      _circles.doc(circleId).collection('joinRequests').doc(uid).delete();

  // ---- owner: approval ----
  Stream<List<JoinRequest>> watchRequests(String circleId) => _circles
      .doc(circleId)
      .collection('joinRequests')
      .snapshots()
      .map((s) => [for (final d in s.docs) JoinRequest.fromMap(circleId, d.data())]);

  Future<void> approveRequest({required String circleId, required String memberUid}) =>
      _circles.doc(circleId).collection('joinRequests').doc(memberUid).update({'status': 'approved'});

  Future<void> rejectRequest({required String circleId, required String memberUid}) =>
      _circles.doc(circleId).collection('joinRequests').doc(memberUid).delete();

  Future<void> setRequiresApproval({required String circleId, required bool value}) =>
      _circles.doc(circleId).update({'requiresApproval': value});

  /// Expiry of a join code (null = never), read from the code document.
  Future<DateTime?> codeExpiry(String code) async {
    final s = await _codes.doc(code).get();
    final e = s.data()?['expiresAt'];
    return e is Timestamp ? e.toDate() : null;
  }

  /// Leaving also deletes the member's location projection in the same atomic batch.
  Future<void> leaveCircle({required String circleId, required String uid}) async {
    final circle = _circles.doc(circleId);
    final name = (await circle.collection('members').doc(uid).get()).data()?['displayName'] as String?;
    final batch = _db.batch();
    if (name != null) {
      batch.set(circle.collection('activity').doc(),
          activityDoc(type: ActivityType.left, actorUid: uid, actorName: name));
    }
    batch.delete(circle.collection('members').doc(uid));
    batch.delete(circle.collection('locations').doc(uid));
    batch.delete(circle.collection('arrivalPlans').doc(uid));
    return batch.commit();
  }

  /// Owner only (enforced by rules). Also removes the member's location projection.
  Future<void> removeMember({
    required String circleId,
    required String memberUid,
    required String ownerUid,
  }) async {
    final circle = _circles.doc(circleId);
    final subject = (await circle.collection('members').doc(memberUid).get()).data()?['displayName'] as String?;
    final owner = (await circle.collection('members').doc(ownerUid).get()).data()?['displayName'] as String?;
    final batch = _db.batch();
    if (subject != null && owner != null) {
      batch.set(
        circle.collection('activity').doc(),
        activityDoc(type: ActivityType.removed, actorUid: ownerUid, actorName: owner, subjectUid: memberUid, subjectName: subject),
      );
    }
    batch.delete(circle.collection('members').doc(memberUid));
    batch.delete(circle.collection('locations').doc(memberUid));
    batch.delete(circle.collection('arrivalPlans').doc(memberUid));
    return batch.commit();
  }

  /// Owner only: revokes the current code and issues a new one atomically.
  Future<void> rotateJoinCode({
    required String circleId,
    required String oldCode,
    required String uid,
    Duration? expiry,
  }) {
    final newCode = generateJoinCode();
    final batch = _db.batch();
    batch.update(_codes.doc(oldCode), {'revoked': true});
    batch.set(_codes.doc(newCode), {
      'circleId': circleId,
      'createdBy': uid,
      'revoked': false,
      'createdAt': FieldValue.serverTimestamp(),
      if (expiry != null) 'expiresAt': Timestamp.fromDate(DateTime.now().add(expiry)),
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

  /// Shares a short, user-selected check-in with this circle without attaching GPS data.
  /// Firestore rules validate membership, the member's current name, and the allowed status.
  Future<void> createCheckIn({
    required String circleId,
    required String uid,
    required String displayName,
    required String status,
    String? placeId,
    String? placeName,
  }) {
    if ((placeId == null) != (placeName == null) ||
        (placeId != null && (placeId.isEmpty || placeName!.trim().isEmpty))) {
      throw ArgumentError('A saved place ID and name must be provided together.');
    }
    if (!kCheckInStatuses.containsKey(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported check-in status');
    }
    return _circles.doc(circleId).collection('activity').doc().set(
          activityDoc(
            type: ActivityType.checkedIn,
            actorUid: uid,
            actorName: displayName,
            checkInStatus: status,
            checkInPlaceId: placeId,
            checkInPlaceName: placeName,
          ),
        );
  }

  Stream<List<ActivityEvent>> watchActivity(String circleId, {int limit = 50}) => _circles
      .doc(circleId)
      .collection('activity')
      .orderBy('occurredAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              if (ActivityEvent.fromMap(circleId, d.id, d.data()) != null) ActivityEvent.fromMap(circleId, d.id, d.data())!,
          ]);

  /// Atomically makes [newOwnerUid] the owner and demotes [ownerUid] to member.
  Future<void> transferOwnership({
    required String circleId,
    required String ownerUid,
    required String newOwnerUid,
  }) {
    final circle = _circles.doc(circleId);
    final batch = _db.batch();
    batch.update(circle, {'ownerUid': newOwnerUid});
    batch.update(circle.collection('members').doc(newOwnerUid), {'role': 'owner'});
    batch.update(circle.collection('members').doc(ownerUid), {'role': 'member'});
    return batch.commit();
  }

  /// Owner only. With no server we delete everything below the circle from the app, then the
  /// circle itself last, so an interrupted run leaves a still-valid (smaller) circle.
  /// History copies are only known for members who had history sharing switched on.
  Future<void> deleteCircle({required String circleId, required String ownerUid}) async {
    final circle = _circles.doc(circleId);
    final members = await circle.collection('members').get();
    final places = await circle.collection('places').get();
    final events = await circle.collection('placeEvents').get();
    final locations = await circle.collection('locations').get();
    final requests = await circle.collection('joinRequests').get();
    final arrivalPlans = await circle.collection('arrivalPlans').get();
    final circleSnap = await circle.get();
    final currentCode = circleSnap.data()?['joinCode'] as String?;

    final refs = <DocumentReference<Map<String, dynamic>>>[
      for (final d in events.docs) d.reference,
      for (final m in members.docs)
        for (final p in places.docs) circle.collection('placeSubscriptions').doc('${m.id}_${p.id}'),
      for (final d in places.docs) d.reference,
      for (final d in locations.docs) d.reference,
      for (final d in arrivalPlans.docs) d.reference,
      for (final d in requests.docs) d.reference,
    ];
    final today = DateTime.now();
    for (final m in members.docs) {
      if (m.data()['historyShared'] == true) {
        for (var i = 0; i <= 92; i++) {
          refs.add(circle.collection('history').doc('${m.id}_${dayKey(today.subtract(Duration(days: i)))}'));
        }
      }
    }
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit();
    }

    // Location documents are gone before membership deletion. Delete membership docs in small
    // batches because the security rules check each member's location with existsAfter(), and
    // Firestore has a per-request document-access-call limit.
    final departingMembers = members.docs.where((m) => m.id != ownerUid).toList();
    for (var i = 0; i < departingMembers.length; i += 10) {
      final batch = _db.batch();
      for (final m in departingMembers.skip(i).take(10)) {
        batch.delete(m.reference);
      }
      await batch.commit();
    }

    var codeExists = false;
    if (currentCode != null && currentCode.isNotEmpty) {
      codeExists = (await _codes.doc(currentCode).get()).exists;
    }
    final last = _db.batch();
    last.delete(circle.collection('members').doc(ownerUid));
    if (codeExists) last.delete(_codes.doc(currentCode!));
    last.delete(circle);
    await last.commit();
  }
}
