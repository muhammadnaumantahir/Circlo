import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_repository.dart';
import 'features/circles/circle_models.dart';
import 'features/circles/circles_repository.dart';
import 'features/location/location_models.dart';
import 'features/location/location_repository.dart';
import 'features/places/geocoder.dart';
import 'features/places/place_models.dart';
import 'features/places/places_repository.dart';
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

final locationRepositoryProvider = Provider<LocationRepository>(
    (ref) => LocationRepository(FirebaseFirestore.instance));

/// The user's own sharing switches per circle.
final myMembershipsProvider = StreamProvider<List<MyMembership>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <MyMembership>[]);
  return ref.watch(locationRepositoryProvider).watchMyMemberships(uid);
});

final locationsProvider = StreamProvider.family<Map<String, MemberLocation>, String>(
    (ref, circleId) => ref.watch(locationRepositoryProvider).watchLocations(circleId));

/// Circle currently shown on the map (null = first circle).
final selectedCircleIdProvider = StateProvider<String?>((ref) => null);

// ---------- Places, alerts and the in-app notification feed (Increment 3) ----------

final placesRepositoryProvider = Provider<PlacesRepository>(
    (ref) => PlacesRepository(FirebaseFirestore.instance));

final placeSearchServiceProvider = Provider<PlaceSearchService>((ref) => PlaceSearchService());

final placesProvider = StreamProvider.family<List<Place>, String>(
    (ref, circleId) => ref.watch(placesRepositoryProvider).watchPlaces(circleId));

final mySubscriptionsProvider = StreamProvider<List<PlaceSubscription>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <PlaceSubscription>[]);
  return ref.watch(placesRepositoryProvider).watchMySubscriptions(uid);
});

final recentEventsProvider = StreamProvider.family<List<PlaceEvent>, String>(
    (ref, circleId) => ref.watch(placesRepositoryProvider).watchRecentEvents(circleId));

/// Events from the last 30 days that match the user's own alert preferences (not their own moves).
final notificationFeedProvider = Provider<AsyncValue<List<FeedItem>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final circlesAsync = ref.watch(myCirclesProvider);
  final subsAsync = ref.watch(mySubscriptionsProvider);
  if (uid == null) return const AsyncValue.data(<FeedItem>[]);
  if (circlesAsync.hasError) return AsyncValue.error(circlesAsync.error!, circlesAsync.stackTrace ?? StackTrace.empty);
  if (subsAsync.hasError) return AsyncValue.error(subsAsync.error!, subsAsync.stackTrace ?? StackTrace.empty);
  final circles = circlesAsync.valueOrNull;
  final subs = subsAsync.valueOrNull;
  if (circles == null || subs == null) return const AsyncValue.loading();

  final subByKey = {for (final s in subs) '${s.circleId}/${s.placeId}': s};
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final items = <FeedItem>[];
  for (final c in circles) {
    final events = ref.watch(recentEventsProvider(c.id)).valueOrNull ?? const <PlaceEvent>[];
    for (final e in events) {
      final at = e.occurredAt;
      if (at == null || at.isBefore(cutoff) || e.memberUid == uid) continue;
      final sub = subByKey['${c.id}/${e.placeId}'];
      if (sub == null || !sub.wants(e.type, e.memberUid)) continue;
      items.add(FeedItem(
        id: '${c.id}/${e.id}',
        circleName: c.name,
        text: '${e.memberName} ${e.isArrival ? 'arrived at' : 'left'} ${e.placeName}',
        at: at,
        isArrival: e.isArrival,
      ));
    }
  }
  items.sort((a, b) => b.at.compareTo(a.at));
  return AsyncValue.data(items);
});
