import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

/// Logging out stops sharing everywhere (best effort; needs a connection) and then signs out.
/// Sharing is never silently resumed on the next log-in: the user switches it on again.
Future<void> signOutStoppingSharing(WidgetRef ref) async {
  final uid = ref.read(currentUidProvider);
  final memberships = ref.read(myMembershipsProvider).valueOrNull ?? const [];
  if (uid != null) {
    final ids = [for (final m in memberships) if (m.sharesLocation) m.circleId];
    if (ids.isNotEmpty) {
      try {
        for (final id in ids) {
          await ref.read(historyRepositoryProvider).removeCopies(uid: uid, circleId: id);
        }
        await ref.read(locationRepositoryProvider).stopSharing(uid: uid, circleIds: ids);
      } catch (_) {
        // Offline: we still sign out; the location is shown as unavailable once it goes stale.
      }
    }
  }
  await ref.read(authRepositoryProvider).signOut();
}
