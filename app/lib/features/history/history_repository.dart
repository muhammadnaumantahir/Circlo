import 'package:cloud_firestore/cloud_firestore.dart';

import 'history_models.dart';

/// Daily history documents: a private master copy per user plus circle-scoped copies that exist
/// only while the user shares history with that circle. Authorization lives in firestore.rules.
class HistoryRepository {
  HistoryRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _master(String uid) =>
      _db.collection('users').doc(uid).collection('history');

  DocumentReference<Map<String, dynamic>> _copy(String circleId, String uid, String day) =>
      _db.collection('circles').doc(circleId).collection('history').doc('${uid}_$day');

  DocumentReference<Map<String, dynamic>> _member(String circleId, String uid) =>
      _db.collection('circles').doc(circleId).collection('members').doc(uid);

  Future<DayTrack?> getMine(String uid, String day) async {
    final s = await _master(uid).doc(day).get();
    final d = s.data();
    return (s.exists && d != null) ? DayTrack.fromMap(d) : null;
  }

  /// Reads a circle member's shared day. Returns null when there is nothing to show
  /// (no data, or the rules deny it because sharing/history sharing is off).
  Future<DayTrack?> getShared(String circleId, String memberUid, String day) async {
    try {
      final s = await _copy(circleId, memberUid, day).get();
      final d = s.data();
      return (s.exists && d != null) ? DayTrack.fromMap(d) : null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Saves the day to the private master copy and to every circle that currently gets history.
  Future<void> saveDay({
    required String uid,
    required DayTrack track,
    required Iterable<String> sharedCircleIds,
  }) {
    final batch = _db.batch();
    final data = track.toMap(uid);
    batch.set(_master(uid).doc(track.day), data);
    for (final id in sharedCircleIds) {
      batch.set(_copy(id, uid, track.day), data);
    }
    return batch.commit();
  }

  /// Day keys of the user's stored history, newest first.
  Future<List<String>> myDays(String uid, {int limit = 200}) async {
    final s = await _master(uid).orderBy('day', descending: true).limit(limit).get();
    return [for (final d in s.docs) d.id];
  }

  /// Reads every stored day key without deleting data while paging.
  /// Account deletion uses this snapshot to remove circle copies before deleting the master keys,
  /// so an interrupted cleanup can be retried without losing the list of days to clean up.
  Future<List<String>> allMyDays(String uid, {int pageSize = 200}) async {
    if (pageSize < 1) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be greater than zero');
    }
    final days = <String>[];
    Query<Map<String, dynamic>> query =
        _master(uid).orderBy('day', descending: true).limit(pageSize);
    while (true) {
      final page = await query.get();
      days.addAll(page.docs.map((d) => d.id));
      if (page.docs.length < pageSize) return days;
      query = _master(uid)
          .orderBy('day', descending: true)
          .startAfterDocument(page.docs.last)
          .limit(pageSize);
    }
  }

  /// Day keys older than the cutoff (yyyymmdd string comparison works for this format).
  Future<List<String>> myDaysBefore(String uid, String cutoffDay) async {
    final s = await _master(uid).where('day', isLessThan: cutoffDay).limit(200).get();
    return [for (final d in s.docs) d.id];
  }

  /// Deletes the given days from the given circles and (unless [includeMaster] is false) from the
  /// private master copy. Deleting an absent circle copy is allowed by the rules.
  Future<void> deleteDays({
    required String uid,
    required List<String> days,
    required Iterable<String> circleIds,
    bool includeMaster = true,
  }) async {
    final ops = <DocumentReference<Map<String, dynamic>>>[];
    for (final day in days) {
      if (includeMaster) ops.add(_master(uid).doc(day));
      for (final c in circleIds) {
        ops.add(_copy(c, uid, day));
      }
    }
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _db.batch();
      for (final r in ops.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  /// Turns history sharing on for one circle. (The current day appears at the next flush.)
  Future<void> enableSharing({required String uid, required String circleId}) =>
      _member(circleId, uid).update({'historyShared': true});

  /// Turns history sharing off for one circle and removes that circle's copies.
  Future<void> disableSharing({required String uid, required String circleId}) async {
    await _member(circleId, uid).update({'historyShared': false});
    await removeCopies(uid: uid, circleId: circleId);
  }

  /// Best effort: delete this circle's copy of every day we still have (used when leaving,
  /// stopping sharing or switching history sharing off).
  Future<void> removeCopies({required String uid, required String circleId}) async {
    try {
      final days = await myDays(uid);
      await deleteDays(uid: uid, days: days, circleIds: [circleId], includeMaster: false);
    } on FirebaseException {
      // Offline or denied: copies stay unreadable anyway once the switches are off.
    }
  }
}
