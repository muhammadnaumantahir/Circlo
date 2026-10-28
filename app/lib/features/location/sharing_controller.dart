import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers.dart';
import '../history/history_recorder.dart';
import '../history/track_builder.dart';
import '../places/place_alert_engine.dart';
import '../places/place_detector.dart';
import '../places/place_models.dart';
import 'location_access.dart';
import 'location_models.dart';
import 'sharing_status.dart';

/// What the sharing engine is doing right now (shown on the map and sharing screens).
class SharingState {
  const SharingState({
    this.tracking = false,
    this.activeCircleIds = const <String>[],
    this.lastPublished,
    this.error,
  });

  final bool tracking;
  final List<String> activeCircleIds;
  final DateTime? lastPublished;
  final String? error;

  SharingState copyWith({
    bool? tracking,
    List<String>? activeCircleIds,
    DateTime? lastPublished,
    String? error,
    bool clearError = false,
  }) =>
      SharingState(
        tracking: tracking ?? this.tracking,
        activeCircleIds: activeCircleIds ?? this.activeCircleIds,
        lastPublished: clearLastPublished ? null : (lastPublished ?? this.lastPublished),
        error: clearError ? null : (error ?? this.error),
      );
}

/// Keeps the device location stream running exactly while the user has sharing ON and not
/// paused for at least one circle, and uploads throttled positions to those circles only.
///
/// Background behaviour (Android foreground service / iOS background updates) is configured
/// below but is NOT verified on real devices yet — see docs/decisions/ADR-0003.
class SharingController extends Notifier<SharingState> {
  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  Position? _last;
  final UploadThrottle _throttle = UploadThrottle();
  PlaceAlertEngine? _engine;
  HistoryRecorder? _history;
  Timer? _resumeTimer;
  List<MyMembership> _memberships = const [];
  int _syncGeneration = 0;
  static const Duration _heartbeatEvery = Duration(minutes: 5);

  @override
  SharingState build() {
    ref.listen<AsyncValue<List<MyMembership>>>(
      myMembershipsProvider,
      (_, next) => _sync(next.valueOrNull ?? const <MyMembership>[]),
      fireImmediately: true,
    );
    // Re-evaluate when the user switches "Keep my travel history" on/off.
    ref.listen(profileProvider, (_, __) => _configureHistory());
    ref.onDispose(() {
      _resumeTimer?.cancel();
      _stop();
    });
    return const SharingState();
  }

  void _configureHistory() {
    final profile = ref.read(profileProvider).valueOrNull;
    _history?.configure(
      keepHistory: profile?.keepHistory ?? false,
      sharedCircleIds: {for (final m in _memberships) if (m.isActive && m.historyShared) m.circleId},
      places: [
        for (final p in _engine?.places ?? const <Place>[])
          NamedPlace(id: p.id, name: p.name, lat: p.lat, lng: p.lng, radiusM: p.radiusM),
      ],
    );
  }

  /// Re-check permissions and restart location listeners, including when a native stream
  /// becomes silent without issuing an error. A membership change cancels this retry.
  Future<void> retry() async {
    final generation = ++_syncGeneration;
    final memberships = List<MyMembership>.unmodifiable(_memberships);
    state = state.copyWith(tracking: false, clearError: true, clearLastPublished: true);
    await _stop();
    if (generation != _syncGeneration) return;
    await _sync(memberships);
  }

  /// Timed pauses end by themselves while the app is running (FR-038).
  void _handleTimedPauses(List<MyMembership> memberships) {
    final uid = ref.read(currentUidProvider);
    final now = DateTime.now();
    _resumeTimer?.cancel();
    if (uid == null) return;
    final expired = [
      for (final m in memberships)
        if (m.sharesLocation && m.paused && m.pausedUntil != null && !m.pausedUntil!.isAfter(now)) m.circleId,
    ];
    if (expired.isNotEmpty) {
      ref
          .read(locationRepositoryProvider)
          .setPausedForCircles(uid: uid, circleIds: expired, paused: false)
          .catchError((_) {}); // retried on the next update
    }
    DateTime? next;
    for (final m in memberships) {
      final u = m.pausedUntil;
      if (m.sharesLocation && m.paused && u != null && u.isAfter(now) && (next == null || u.isBefore(next))) next = u;
    }
    if (next != null) {
      _resumeTimer = Timer(next.difference(now) + const Duration(seconds: 1), () => _handleTimedPauses(_memberships));
    }
  }

  Future<void> _sync(List<MyMembership> memberships) async {
    final generation = ++_syncGeneration;
    _memberships = List<MyMembership>.unmodifiable(memberships);
    _handleTimedPauses(memberships);
    final active = [for (final m in memberships) if (m.isActive) m.circleId];
    if (active.isEmpty) {
      await _stop();
      if (generation != _syncGeneration) return;
      state = const SharingState();
      return;
    }

    final access = await currentLocationAccess();
    if (generation != _syncGeneration) return;
    if (access != LocationAccess.granted) {
      await _stop();
      if (generation != _syncGeneration) return;
      state = SharingState(
        activeCircleIds: active,
        error: 'Location permission is needed to share. Open Location sharing to fix this.',
      );
      return;
    }

    final scopeChanged = !listEquals(state.activeCircleIds, active);
    state = state.copyWith(
      activeCircleIds: active,
      clearError: true,
      clearLastPublished: scopeChanged,
    );
    await _start(generation: generation);
    if (generation != _syncGeneration) return;
    await _engine?.setCircles(active.toSet());
    if (generation != _syncGeneration) return;
    _configureHistory();
  }

  LocationSettings _settings() {
    const distance = 25; // metres between updates while moving
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distance);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distance,
          intervalDuration: const Duration(seconds: 30),
          // The persistent notification keeps sharing visible and the process alive (FR-037).
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Circlo is sharing your location',
            notificationText: 'Open Circlo to pause or stop sharing at any time.',
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.other,
          distanceFilter: distance,
          pauseLocationUpdatesAutomatically: true,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distance);
    }
  }

  Future<void> _start({required int generation}) async {
    if (_sub != null) return;
    _throttle.reset();
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      _engine = PlaceAlertEngine(repository: ref.read(placesRepositoryProvider), uid: uid);
      _history = HistoryRecorder(repository: ref.read(historyRepositoryProvider), uid: uid);
    }
    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
      (p) {
        _last = p;
        _feedEngine(p);
        _publish(p);
      },
      onError: (Object e) {
        // Do not keep the heartbeat publishing a stale position after the OS revokes location
        // access or the position stream fails. Stop the stream and engines; the user can retry.
        unawaited(_handleLocationStreamError(_syncGeneration));
      },
    );
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) {
      final p = _last;
      if (p != null) {
        _feedEngine(p, now: true); // a stationary phone still confirms arrivals by elapsed time
        _publish(p, force: true); // keeps "last updated" fresh while stationary
      }
    });
    state = state.copyWith(tracking: true, clearError: true);
    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      if (generation != _syncGeneration || _sub == null) return;
      _last = first;
      await _publish(first, force: true);
    } catch (_) {
      // Do not leave the sharing screen in an endless "connecting" state when neither the
      // stream nor getCurrentPosition can provide a first fix. Surface a retry action instead.
      if (generation == _syncGeneration && _sub != null && state.lastPublished == null) {
        state = state.copyWith(
          error: 'Could not get your location. Check location permission, GPS and device settings.',
        );
      }
    }
  }

  void _feedEngine(Position p, {bool now = false}) {
    final time = now ? DateTime.now() : p.timestamp;
    _configureHistory(); // places may have changed since the last fix
    _history?.onFix(lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, time: time);
    _engine?.onFix(Fix(
      lat: p.latitude,
      lng: p.longitude,
      accuracy: p.accuracy,
      time: now ? DateTime.now() : p.timestamp,
    ));
  }

  Future<void> _handleLocationStreamError(int generation) async {
    try {
      await _stop();
    } catch (_) {
      // Preserve the actionable location error even if best-effort flush/cleanup also fails.
    }
    // A newer permission check or sharing-switch change supersedes this stream error.
    if (generation != _syncGeneration) return;
    state = state.copyWith(
      tracking: false,
      error: 'Could not read your location. Check location permission and device settings.',
    );
  }

  Future<void> _stop() async {
    // Detach every resource before the first await. A newer sync may start fresh resources
    // while cancellation/flush below is still finishing; this cleanup must never dispose those.
    _heartbeat?.cancel();
    _heartbeat = null;
    final sub = _sub;
    final history = _history;
    final engine = _engine;
    _sub = null;
    _history = null;
    _engine = null;
    _last = null;

    try {
      await sub?.cancel();
    } catch (_) {
      // Continue cleanup even when the platform stream fails to cancel cleanly.
    }
    try {
      await history?.dispose();
    } catch (_) {
      // History is best-effort on offline/quota failures; it must not keep location tracking alive.
    }
    try {
      await engine?.dispose();
    } catch (_) {
      // Dispose remaining resources even if one listener has already failed.
    }
  }

  Future<void> _publish(Position p, {bool force = false}) async {
    final uid = ref.read(currentUidProvider);
    final ids = state.activeCircleIds;
    if (uid == null || ids.isEmpty) return;
    final now = DateTime.now();
    if (!force && !_throttle.allow(now)) return;
    if (force) _throttle.allow(now);
    try {
      await ref.read(locationRepositoryProvider).publish(
            uid: uid,
            circleIds: ids,
            lat: p.latitude,
            lng: p.longitude,
            accuracy: p.accuracy,
          );
      state = state.copyWith(lastPublished: now, clearError: true);
    } on FirebaseException {
      state = state.copyWith(error: 'Sync delayed. We will retry with the next update.');
    }
  }
}

final sharingControllerProvider =
    NotifierProvider<SharingController, SharingState>(SharingController.new);
