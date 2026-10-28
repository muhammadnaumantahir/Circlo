import '../../core/geo.dart';

/// Pure arrival/departure state machine (ADR-0002, architecture §7). No Firebase/Flutter imports.
///
/// Arrival: inside the radius for 2 consecutive fixes OR for >= 2 minutes.
/// Departure: outside radius x 1.2 (hysteresis) for 2 consecutive fixes OR >= 2 minutes.
/// Fixes with accuracy worse than [maxAccuracyM] are ignored. One visit = one arrive + one leave.
class PlacePoint {
  const PlacePoint({required this.id, required this.lat, required this.lng, required this.radiusM});
  final String id;
  final double lat;
  final double lng;
  final double radiusM;
}

class Fix {
  const Fix({required this.lat, required this.lng, required this.accuracy, required this.time});
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime time;
}

enum TransitionType { arrive, leave }

class PlaceTransition {
  const PlaceTransition({required this.placeId, required this.type, required this.visitId, required this.time});
  final String placeId;
  final TransitionType type;
  final String visitId;
  final DateTime time;
}

class _PlaceState {
  bool inside = false;
  String? visitId;
  DateTime? pendingSince;
  int pendingCount = 0;
  DateTime? lastFixAt;

  void clearPending() {
    pendingSince = null;
    pendingCount = 0;
  }
}

bool _validCoordinate(double lat, double lng) =>
    lat.isFinite && lng.isFinite && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

class PlaceDetector {
  PlaceDetector({
    this.maxAccuracyM = 100,
    this.confirmFixes = 2,
    this.confirmDuration = const Duration(minutes: 2),
    this.exitFactor = 1.2,
  });

  final double maxAccuracyM;
  final int confirmFixes;
  final Duration confirmDuration;
  final double exitFactor;
  final Map<String, _PlaceState> _states = {};

  _PlaceState _state(String placeId) => _states.putIfAbsent(placeId, _PlaceState.new);

  /// Restore the latest known state of a place after an app restart or share pause.
  /// Passing [inside] as false is important after a previous visit ended: stale state must
  /// never turn the next fix into a duplicate departure for the old visit.
  void restoreState(String placeId, {required bool inside, String? visitId}) {
    final s = _state(placeId);
    s.inside = inside;
    s.visitId = inside ? visitId : null;
    s.clearPending();
  }

  /// Backwards-compatible helper for restoring an active visit.
  void restoreInside(String placeId, String visitId) =>
      restoreState(placeId, inside: true, visitId: visitId);

  /// Clear transient state for a place that was removed from active tracking.
  void forget(String placeId) => _states.remove(placeId);

  bool isInside(String placeId) => _states[placeId]?.inside ?? false;

  /// Forget places that no longer exist.
  void retainOnly(Set<String> placeIds) =>
      _states.removeWhere((id, _) => !placeIds.contains(id));

  void reset() => _states.clear();

  List<PlaceTransition> process(Fix fix, Iterable<PlacePoint> places) {
    // Bad GPS samples must never affect visit state or emit false arrival/departure events.
    if (!_validCoordinate(fix.lat, fix.lng) ||
        !fix.accuracy.isFinite ||
        fix.accuracy < 0 ||
        fix.accuracy > maxAccuracyM) {
      return const [];
    }
    final out = <PlaceTransition>[];
    for (final p in places) {
      if (!_validCoordinate(p.lat, p.lng) || !p.radiusM.isFinite || p.radiusM <= 0) continue;
      final st = _state(p.id);
      // Location callbacks can arrive out of order after retries or stream reconnection.
      // Older samples must not advance the confirmation counter or create a transition.
      if (st.lastFixAt != null && fix.time.isBefore(st.lastFixAt!)) continue;
      st.lastFixAt = fix.time;
      final d = distanceMeters(fix.lat, fix.lng, p.lat, p.lng);
      final condition = st.inside ? d > p.radiusM * exitFactor : d <= p.radiusM;
      if (!condition) {
        st.clearPending();
        continue;
      }
      st.pendingCount++;
      st.pendingSince ??= fix.time;
      final confirmed = st.pendingCount >= confirmFixes ||
          fix.time.difference(st.pendingSince!) >= confirmDuration;
      if (!confirmed) continue;

      if (st.inside) {
        out.add(PlaceTransition(
            placeId: p.id, type: TransitionType.leave, visitId: st.visitId ?? '0', time: fix.time));
        st.inside = false;
        st.visitId = null;
      } else {
        st.inside = true;
        st.visitId = fix.time.millisecondsSinceEpoch.toString();
        out.add(PlaceTransition(
            placeId: p.id, type: TransitionType.arrive, visitId: st.visitId!, time: fix.time));
      }
      st.clearPending();
    }
    return out;
  }
}
