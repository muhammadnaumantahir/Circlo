import 'package:cloud_firestore/cloud_firestore.dart';

import 'history_models.dart';
import 'history_repository.dart';
import 'track_builder.dart';

typedef HistoryDayLoader = Future<DayTrack?> Function(String uid, String day);
typedef HistoryDayWriter = Future<void> Function(
  String uid,
  DayTrack track,
  Iterable<String> sharedCircleIds,
);

/// Turns the live location stream into the user's daily history and stores it with few writes:
/// at most one write batch every [flushEvery] (plus one when a visit starts or ends).
///
/// History is only recorded while location sharing is running AND the user switched on
/// "Keep my travel history". Copies go to a circle only if history sharing is on for it.
class HistoryRecorder {
  HistoryRecorder({
    HistoryRepository? repository,
    required this.uid,
    this.flushEvery = const Duration(minutes: 5),
    HistoryDayLoader? loadDay,
    HistoryDayWriter? saveDay,
  })  : _loadDay = loadDay ??
            ((uid, day) => repository!.getMine(uid, day)),
        _saveDay = saveDay ??
            ((uid, track, circles) => repository!.saveDay(
                  uid: uid,
                  track: track,
                  sharedCircleIds: circles,
                )) {
    if (repository == null && (loadDay == null || saveDay == null)) {
      throw ArgumentError(
        'Provide a repository or both history read/write callbacks.',
      );
    }
  }

  final String uid;
  final Duration flushEvery;
  final HistoryDayLoader _loadDay;
  final HistoryDayWriter _saveDay;

  final TrackBuilder _builder = TrackBuilder();
  Set<String> _sharedCircles = {};
  List<NamedPlace> _places = const [];
  bool _keep = false;
  bool _restored = false;
  Future<void>? _restorePending;
  // GPS callbacks may overlap while a Firestore restore/flush is awaiting network I/O.
  // Process them in arrival order so mutable track state cannot change mid-write.
  Future<void> _fixQueue = Future<void>.value();
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
  }) {
    final operation = _fixQueue.then(
      (_) => _processFix(lat: lat, lng: lng, accuracy: accuracy, time: time),
    );
    // Do not let an unexpected callback failure permanently block later GPS fixes.
    _fixQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<void> _processFix({
    required double lat,
    required double lng,
    required double accuracy,
    required DateTime time,
  }) async {
    if (!_keep) return;
    try {
      await _ensureRestored(time);
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

  Future<void> _ensureRestored(DateTime time) async {
    if (_restored) return;

    // Concurrent location callbacks share the same first read. Otherwise each callback could
    // restore the same stale snapshot and overwrite state processed by another callback.
    final pending = _restorePending;
    if (pending != null) {
      await pending;
      return;
    }

    final restore = _loadAndRestore(time);
    _restorePending = restore;
    try {
      await restore;
    } finally {
      if (identical(_restorePending, restore)) _restorePending = null;
    }
  }

  Future<void> _loadAndRestore(DateTime time) async {
    // Mark restored only after the read succeeds. If Firestore is offline on startup,
    // retry on a later fix instead of overwriting an existing day's history with a blank track.
    final existing = await _loadDay(uid, dayKey(time));
    if (existing != null) _builder.restore(existing);
    _restored = true;
  }

  Future<void> _write(DayTrack t) =>
      _saveDay(uid, t, _sharedCircles);

  /// Called when sharing stops/pauses: close the current stop and store what we have.
  Future<void> dispose() async {
    // Sharing shutdown cancels the stream first; drain queued callbacks before closing the
    // active visit so no pending fix can mutate the track after its final flush.
    await _fixQueue;
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
