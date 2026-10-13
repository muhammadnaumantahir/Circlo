import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_repository.dart';
import 'features/circles/circle_models.dart';
import 'features/circles/circles_repository.dart';
import 'features/profile/profile_models.dart';
import 'features/profile/profile_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(FirebaseAuth.instance));
final profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(FirebaseFirestore.instance));
final circlesRepositoryProvider = Provider<CirclesRepository>(
    (ref) => CirclesRepository(FirebaseFirestore.instance));

final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(authRepositoryProvider).authStateChanges());

final currentUidProvider =
    Provider<String?>((ref) => ref.watch(authStateProvider).valueOrNull?.uid);

/// Emits null when the signed-in user has no profile document yet.
final profileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(uid);
});

final myCirclesProvider = StreamProvider<List<Circle>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <Circle>[]);
  return ref.watch(circlesRepositoryProvider).watchMyCircles(uid);
});

final circleProvider = StreamProvider.family<Circle?, String>(
    (ref, id) => ref.watch(circlesRepositoryProvider).watchCircle(id));

final membersProvider = StreamProvider.family<List<Member>, String>(
    (ref, id) => ref.watch(circlesRepositoryProvider).watchMembers(id));

/// Birth year typed at sign-up, used to pre-fill profile setup.
final signupBirthYearProvider = StateProvider<int?>((ref) => null);
