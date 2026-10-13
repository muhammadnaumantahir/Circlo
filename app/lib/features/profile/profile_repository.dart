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
