/// Pure helpers for how a member's sharing state is shown (FR-031, FR-032).
enum ShareStatus { sharing, paused, unavailable, notSharing }

const Duration kStaleAfter = Duration(minutes: 10);

/// A location fix is fresh only when it is recent and not implausibly far in the future.
bool isLocationFixFresh({
  required DateTime capturedAt,
  required DateTime now,
  Duration maxAge = kStaleAfter,
  Duration futureTolerance = const Duration(minutes: 2),
}) =>
    !capturedAt.isAfter(now.add(futureTolerance)) && now.difference(capturedAt) <= maxAge;

ShareStatus deriveStatus({
  required bool sharesLocation,
  required bool paused,
  required DateTime? updatedAt,
  required DateTime now,
  Duration staleAfter = kStaleAfter,
}) {
  if (!sharesLocation) return ShareStatus.notSharing;
  if (paused) return ShareStatus.paused;
  if (updatedAt == null) return ShareStatus.unavailable;
  // A materially future-dated server timestamp is not evidence of a live location.
  // Allow small device/server clock skew, matching isLocationFixFresh().
  if (updatedAt.isAfter(now.add(const Duration(minutes: 2)))) return ShareStatus.unavailable;
  if (now.difference(updatedAt) > staleAfter) return ShareStatus.unavailable;
  return ShareStatus.sharing;
}

String statusLabel(ShareStatus s) {
  switch (s) {
    case ShareStatus.sharing:
      return 'Sharing';
    case ShareStatus.paused:
      return 'Paused';
    case ShareStatus.unavailable:
      return 'Location unavailable';
    case ShareStatus.notSharing:
      return 'Not sharing with this circle';
  }
}

/// "just now", "5 min ago", "3 h ago", "2 d ago".
String formatAgo(DateTime? time, DateTime now) {
  if (time == null) return 'never';
  final d = now.difference(time);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Limits how often a position is uploaded (free-tier write budget, NFR-016).
class UploadThrottle {
  UploadThrottle({this.minInterval = const Duration(seconds: 30)});

  final Duration minInterval;
  DateTime? _last;

  bool allow(DateTime now) {
    final last = _last;
    if (last == null || now.difference(last) >= minInterval) {
      _last = now;
      return true;
    }
    return false;
  }

  void reset() => _last = null;
}
