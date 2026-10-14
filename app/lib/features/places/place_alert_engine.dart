import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'place_detector.dart';
import 'place_models.dart';
import 'places_repository.dart';

class _PendingEvent {
  _PendingEvent(this.place, this.type, this.visitId);
  final Place place;
  final String type;
  final String visitId;
}

/// Runs the on-device detector against the places of every circle this device is actively
/// sharing with, and publishes de-duplicated arrival/departure events (ADR-0002).
///
/// Limits (documented, deliberate): events are only created while the app is receiving location
/// updates; alerts reach other members only through the in-app feed (remote push is deferred).
class PlaceAlertEngine {
  PlaceAlertEngine({required this.repository, required this.uid});

  final PlacesRepository repository;
  final String uid;

  final PlaceDetector _detector = PlaceDetector();
  final Map<String, List<Place>> _placesByCircle = {};
  final Map<String, StreamSubscription<List<Place>>> _subs = {};
  final List<_PendingEvent> _pending = [];
  final Map<String, String> _names = {}; // circleId -> my display name in that circle

  /// Saved places of the circles currently followed.
  List<Place> get places => [for (final l in _placesByCircle.values) ...l];

  /// Follows exactly the given circles (those with sharing on and not paused).
  Future<void> setCircles(Set<String> circleIds) async {
    for (final id in _subs.keys.toList()) {
      if (!circleIds.contains(id)) {
        await _subs.remove(id)?.cancel();
        _placesByCircle.remove(id);
        _names.remove(id);
      }
    }
    for (final id in circleIds) {
      if (_subs.containsKey(id)) continue;
      try {
        final n = await repository.myMemberName(id, uid);
        if (n != null) _names[id] = n;
      } on FirebaseException {
        // events for this circle are skipped until the name is known
      }
      // Restore "inside" state from our own latest events before judging new fixes.
      try {
        final events = await repository.myLatestEvents(id, uid);
        final seen = <String>{};
        for (final e in events) {
          if (!seen.add(e.placeId)) continue; // newest event per place wins
          if (e.isArrival) _detector.restoreInside(e.placeId, e.visitId);
        }
      } on FirebaseException {
        // Without restore we might repeat an "arrived"; acceptable, rules reject exact duplicates.
      }
      _subs[id] = repository.watchPlaces(id).listen(
        (places) {
          _placesByCircle[id] = places;
          _detector.retainOnly({for (final l in _placesByCircle.values) for (final p in l) p.id});
        },
        onError: (_) {},
      );
    }
  }

  Future<void> onFix(Fix fix) async {
    final all = [for (final l in _placesByCircle.values) ...l];
    if (all.isNotEmpty) {
      final byId = {for (final p in all) p.id: p};
      final transitions = _detector.process(fix, [
        for (final p in all) PlacePoint(id: p.id, lat: p.lat, lng: p.lng, radiusM: p.radiusM),
      ]);
      for (final t in transitions) {
        final place = byId[t.placeId];
        if (place == null) continue;
        _pending.add(_PendingEvent(
            place, t.type == TransitionType.arrive ? 'arrive' : 'leave', t.visitId));
      }
    }
    await _flush();
  }

  Future<void> _flush() async {
    for (final e in List<_PendingEvent>.of(_pending)) {
      final name = _names[e.place.circleId];
      if (name == null) continue; // retry once the member name has been loaded
      try {
        await repository.publishEvent(
          circleId: e.place.circleId,
          uid: uid,
          memberName: name,
          place: e.place,
          type: e.type,
          visitId: e.visitId,
        );
        _pending.remove(e);
      } on FirebaseException catch (ex) {
        // permission-denied = duplicate/forbidden (sharing paused, place renamed...): drop it.
        // Anything else (offline, quota): keep and retry on the next fix, up to a small cap.
        if (ex.code == 'permission-denied' || _pending.length > 20) {
          _pending.remove(e);
        }
      }
    }
  }

  Future<void> dispose() async {
    for (final s in _subs.values) {
      await s.cancel();
    }
    _subs.clear();
    _placesByCircle.clear();
    _names.clear();
    _pending.clear();
    _detector.reset();
  }
}
