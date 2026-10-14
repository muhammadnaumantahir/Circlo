import 'package:cloud_firestore/cloud_firestore.dart';

import 'history_models.dart';
import 'history_repository.dart';
import 'track_builder.dart';

/// Turns the live location stream into the user's daily history and stores it with few writes:
/// at most one write batch every [flushEvery] (plus one when a visit starts or ends).
///
/// History is only recorded while location sharing is running AND the user switched on
/// "Keep my travel history". Copies go to a circle only if history sharing is on for it.
class HistoryRecorder {
  HistoryRecorder({
    required this.repository,
    required this.uid,
    this.flushEvery = const Duration(minutes: 5),
  });

  final HistoryRepository repository;
  final String uid;
  final Duration flushEvery;

  final TrackBuilder _builder = TrackBuilder();
  Set<String> _sharedCircles = {};
  List<NamedPlace> _places = const [];
  bool _keep = false;
  bool _restored = false;
  bool _dirty = false;
  DateTime? _lastFlush;
  String _signature = '';

  void configure({
    required bool keepHistory,
    required Set<String> sharedCircleIds,
    required List<NamedPlace> places,
  }) {
    _keep = keepHistory;
    _sharedCircles = sharedCircleIds;
    _places = places;
  }

  Future<void> onFix({
    required double lat,
    required double lng,
    required double accuracy,
    required DateTime time,
  }) async {
    if (!_keep) return;
    try {
      if (!_restored) {
        _restored = true;
        final existing = await repository.getMine(uid, dayKey(time));
        if (existing != null) _builder.restore(existing);
      }
      final before = _builder.current;
      final changed = _builder.process(
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        time: time,
        places: _places,
        tzOffsetMin: time.toLocal().timeZoneOffset.inMinutes,
      );
      final after = _builder.current;
      if (before != null && !identical(before, after)) {
        await _write(before); // persist the finished day (its open visit was closed)
      }
      if (changed) _dirty = true;
      final sig = _visitSignature(after);
      final visitChanged = sig != _signature;
      _signature = sig;
      final due = _lastFlush == null || DateTime.now().difference(_lastFlush!) >= flushEvery;
      if (_dirty && (due || visitChanged)) await flush();
    } on FirebaseException {
      // Offline or quota: keep the data in memory and retry on a later fix.
    }
  }

  String _visitSignature(DayTrack? t) {
    if (t == null) return '';
    final closed = t.visits.where((v) => v.leftAt != null).length;
    return '${t.day}:${t.visits.length}:$closed';
  }

  Future<void> flush() async {
    final t = _builder.current;
    if (t == null || !_dirty) return;
    await _write(t);
    _dirty = false;
    _lastFlush = DateTime.now();
  }

  Future<void> _write(DayTrack t) =>
      repository.saveDay(uid: uid, track: t, sharedCircleIds: _sharedCircles);

  /// Called when sharing stops/pauses: close the current stop and store what we have.
  Future<void> dispose() async {
    if (!_keep || _builder.current == null) return;
    try {
      _builder.closeOpenVisit();
      _dirty = true;
      await flush();
    } on FirebaseException {
      // best effort
    }
  }
}
