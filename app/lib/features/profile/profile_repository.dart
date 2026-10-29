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
  }) {
    final cleanPhone = phone?.trim() ?? '';
    return _doc(uid).update({
      'displayName': displayName.trim(),
      'phone': cleanPhone.isEmpty ? FieldValue.delete() : cleanPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
