import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_repository.dart';
import 'features/circles/circle_models.dart';
import 'features/circles/circles_repository.dart';
import 'features/circles/activity.dart';
import 'features/history/history_models.dart';
import 'features/history/history_repository.dart';
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

final activityProvider = StreamProvider.family<List<ActivityEvent>, String>(
    (ref, circleId) => ref.watch(circlesRepositoryProvider).watchActivity(circleId));

/// Re-evaluates time-based notices (location unavailable) once a minute.
final _minuteTickProvider = StreamProvider<int>((ref) => Stream.periodic(const Duration(minutes: 1), (i) => i));

/// Everything the user may want to know, newest first, after applying their notification settings:
/// place arrivals/departures (per place preferences), membership and sharing changes, locations that
/// became unavailable (>= 15 min without an update, once per outage) and join requests for owned circles.
/// In-app only: remote push is not available under the zero-budget scope.
final notificationFeedProvider = Provider<AsyncValue<List<FeedItem>>>((ref) {
  ref.watch(_minuteTickProvider);
  final uid = ref.watch(currentUidProvider);
  final circlesAsync = ref.watch(myCirclesProvider);
  final subsAsync = ref.watch(mySubscriptionsProvider);
  final profile = ref.watch(profileProvider).valueOrNull;
  if (uid == null) return const AsyncValue.data(<FeedItem>[]);
  if (circlesAsync.hasError) return AsyncValue.error(circlesAsync.error!, circlesAsync.stackTrace ?? StackTrace.empty);
  if (subsAsync.hasError) return AsyncValue.error(subsAsync.error!, subsAsync.stackTrace ?? StackTrace.empty);
  final circles = circlesAsync.valueOrNull;
  final subs = subsAsync.valueOrNull;
  if (circles == null || subs == null) return const AsyncValue.loading();

  final off = (profile?.notifOff ?? const <String>[]).toSet();
  final muted = (profile?.notifMuted ?? const <String>[]).toSet();
  bool wants(FeedKind k) => !off.contains(feedKindName(k));

  final subByKey = {for (final s in subs) '${s.circleId}/${s.placeId}': s};
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final items = <FeedItem>[];

  for (final c in circles) {
    if (muted.contains(c.id)) continue;

    if (wants(FeedKind.place)) {
      for (final e in ref.watch(recentEventsProvider(c.id)).valueOrNull ?? const <PlaceEvent>[]) {
        final at = e.occurredAt;
        if (at == null || at.isBefore(cutoff)) continue;
        if (e.isCheckIn) {
          items.add(FeedItem(
            id: '${c.id}/${e.id}',
            circleId: c.id,
            circleName: c.name,
            kind: FeedKind.place,
            text: e.memberUid == uid ? 'You checked in at ${e.placeName}' : '${e.memberName} checked in at ${e.placeName}',
            at: at,
            isCheckIn: true,
            actorUid: e.memberUid,
            eventId: e.id,
          ));
          continue;
        }
        if (e.memberUid == uid) continue;
        final sub = subByKey['${c.id}/${e.placeId}'];
        if (sub == null || !sub.wants(e.type, e.memberUid)) continue;
        items.add(FeedItem(
          id: '${c.id}/${e.id}',
          circleId: c.id,
          circleName: c.name,
          kind: FeedKind.place,
          text: '${e.memberName} ${e.isArrival ? 'arrived at' : 'left'} ${e.placeName}',
          at: at,
          isArrival: e.isArrival,
        ));
      }
    }

    final wantMembership = wants(FeedKind.membership);
    final wantSharing = wants(FeedKind.sharing);
    if (wantMembership || wantSharing) {
      for (final a in ref.watch(activityProvider(c.id)).valueOrNull ?? const <ActivityEvent>[]) {
        final at = a.occurredAt;
        if (at == null || at.isBefore(cutoff) || a.actorUid == uid) continue;
        final isSharing = a.type == ActivityType.sharingStarted || a.type == ActivityType.sharingStopped;
        if (isSharing ? !wantSharing : !wantMembership) continue;
        items.add(FeedItem(
          id: '${c.id}/act/${a.id}',
          circleId: c.id,
          circleName: c.name,
          kind: isSharing ? FeedKind.sharing : FeedKind.membership,
          text: a.text,
          at: at,
        ));
      }
    }

    if (wants(FeedKind.unavailable)) {
      final members = ref.watch(membersProvider(c.id)).valueOrNull ?? const <Member>[];
      final locations = ref.watch(locationsProvider(c.id)).valueOrNull ?? const <String, MemberLocation>{};
      for (final m in members) {
        if (m.uid == uid || !m.sharesLocation || m.paused) continue;
        final updated = locations[m.uid]?.updatedAt;
        if (updated == null) continue;
        final since = updated.add(const Duration(minutes: 15));
        if (since.isAfter(now) || since.isBefore(cutoff)) continue;
        items.add(FeedItem(
          id: '${c.id}/${m.uid}/unavailable/${updated.millisecondsSinceEpoch}',
          circleId: c.id,
          circleName: c.name,
          kind: FeedKind.unavailable,
          text: "${m.displayName}'s location is unavailable (no update for 15+ minutes)",
          at: since,
        ));
      }
    }

    if (c.ownerUid == uid && wants(FeedKind.requests)) {
      for (final r in ref.watch(circleRequestsProvider(c.id)).valueOrNull ?? const <JoinRequest>[]) {
        if (r.approved) continue;
        items.add(FeedItem(
          id: '${c.id}/request/${r.uid}',
          circleId: c.id,
          circleName: c.name,
          kind: FeedKind.requests,
          text: '${r.displayName} asked to join ${c.name}',
          at: r.createdAt ?? now,
        ));
      }
    }
  }
  items.sort((a, b) => b.at.compareTo(a.at));
  return AsyncValue.data(items);
});

/// Items newer than the last time the user opened the notifications list.
final unreadCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationFeedProvider).valueOrNull ?? const <FeedItem>[];
  final seen = ref.watch(profileProvider).valueOrNull?.notifSeenAt;
  if (seen == null) return items.length;
  return items.where((i) => i.at.isAfter(seen)).length;
});

// ---------- Travel history (Increment 4) ----------

final historyRepositoryProvider = Provider<HistoryRepository>(
    (ref) => HistoryRepository(FirebaseFirestore.instance));

/// (circleId, memberUid, dayKey) -> that member's day, or null when there is nothing to show.
final dayTrackProvider = FutureProvider.autoDispose.family<DayTrack?, (String, String, String)>((ref, key) async {
  final uid = ref.watch(currentUidProvider);
  final (circleId, memberUid, day) = key;
  final repo = ref.watch(historyRepositoryProvider);
  if (uid == null) return null;
  return memberUid == uid ? repo.getMine(uid, day) : repo.getShared(circleId, memberUid, day);
});

/// Deletes history older than the user's retention period (best effort, client-side: there is no
/// server to do it). Safe to call repeatedly.
Future<void> runRetentionCleanup(WidgetRef ref) async {
  final uid = ref.read(currentUidProvider);
  final profile = ref.read(profileProvider).valueOrNull;
  if (uid == null || profile == null) return;
  final memberships = ref.read(myMembershipsProvider).valueOrNull ?? const <MyMembership>[];
  final repo = ref.read(historyRepositoryProvider);
  try {
    final cutoff = dayKey(DateTime.now().subtract(Duration(days: profile.retentionDays)));
    final old = await repo.myDaysBefore(uid, cutoff);
    if (old.isEmpty) return;
    await repo.deleteDays(uid: uid, days: old, circleIds: [for (final m in memberships) m.circleId]);
  } catch (_) {
    // offline or denied: try again next time
  }
}

// ---------- Circle lifecycle (Increment 5) ----------

final myJoinRequestsProvider = StreamProvider<List<JoinRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <JoinRequest>[]);
  return ref.watch(circlesRepositoryProvider).watchMyRequests(uid);
});

final circleRequestsProvider = StreamProvider.family<List<JoinRequest>, String>(
    (ref, circleId) => ref.watch(circlesRepositoryProvider).watchRequests(circleId));

final codeExpiryProvider = FutureProvider.autoDispose.family<DateTime?, String>(
    (ref, code) => ref.watch(circlesRepositoryProvider).codeExpiry(code));

/// Switches location/history sharing off in every circle (best effort). Used before deleting an account.
final sharingStopperProvider = Provider<Future<void> Function()>((ref) => () async {
      final uid = ref.read(currentUidProvider);
      final memberships = ref.read(myMembershipsProvider).valueOrNull ?? const <MyMembership>[];
      if (uid == null) return;
      final ids = [for (final m in memberships) if (m.sharesLocation) m.circleId];
      if (ids.isEmpty) return;
      final history = ref.read(historyRepositoryProvider);
      for (final id in ids) {
        await history.removeCopies(uid: uid, circleId: id);
      }
      await ref.read(locationRepositoryProvider).stopSharing(uid: uid, circleIds: ids);
    });
