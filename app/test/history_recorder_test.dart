import 'dart:async';

import 'package:circlo/features/history/history_models.dart';
import 'package:circlo/features/history/history_recorder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent initial fixes share a single history restore read', () async {
    final restore = Completer<DayTrack?>();
    var reads = 0;
    var writes = 0;

    final recorder = HistoryRecorder(
      uid: 'u1',
      loadDay: (uid, day) {
        expect(uid, 'u1');
        expect(day, '20261029');
        reads++;
        return restore.future;
      },
      saveDay: (uid, track, sharedCircleIds) async {
        writes++;
      },
    )..configure(
        keepHistory: true,
        sharedCircleIds: <String>{},
        places: const [],
      );

    final first = recorder.onFix(
      lat: 31.52,
      lng: 74.35,
      accuracy: 10,
      time: DateTime(2026, 10, 29, 8),
    );
    final second = recorder.onFix(
      lat: 31.52,
      lng: 74.35,
      accuracy: 10,
      time: DateTime(2026, 10, 29, 8, 1),
    );

    expect(reads, 1);
    restore.complete(null);
    await Future.wait([first, second]);

    expect(reads, 1);
    expect(writes, greaterThan(0));
  });

  test('a second fix cannot mutate track state while the first flush is pending', () async {
    final writeStarted = Completer<void>();
    final releaseWrite = Completer<void>();
    DayTrack? firstTrack;
    var writes = 0;
    final firstTime = DateTime(2026, 10, 29, 8);

    final recorder = HistoryRecorder(
      uid: 'u1',
      loadDay: (uid, day) async => null,
      saveDay: (uid, track, sharedCircleIds) async {
        writes++;
        if (writes == 1) {
          firstTrack = track;
          writeStarted.complete();
          await releaseWrite.future;
        }
      },
    )..configure(
        keepHistory: true,
        sharedCircleIds: <String>{},
        places: const [],
      );

    final first = recorder.onFix(
      lat: 31.52,
      lng: 74.35,
      accuracy: 10,
      time: firstTime,
    );
    await writeStarted.future;

    final second = recorder.onFix(
      lat: 31.52,
      lng: 74.35,
      accuracy: 10,
      time: firstTime.add(const Duration(minutes: 1)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(firstTrack!.lastSeen, firstTime.millisecondsSinceEpoch);
    releaseWrite.complete();
    await Future.wait([first, second]);

    expect(firstTrack!.lastSeen, firstTime.add(const Duration(minutes: 1)).millisecondsSinceEpoch);
  });

  test('a failed initial restore can be retried on a later fix', () async {
    var reads = 0;
    final recorder = HistoryRecorder(
      uid: 'u1',
      loadDay: (uid, day) async {
        reads++;
        if (reads == 1) {
          throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
        }
        return null;
      },
      saveDay: (uid, track, sharedCircleIds) async {},
    )..configure(
        keepHistory: true,
        sharedCircleIds: <String>{},
        places: const [],
      );

    await recorder.onFix(
      lat: 31.52,
      lng: 74.35,
      accuracy: 10,
      time: DateTime(2026, 10, 29, 8),
    );
    await recorder.onFix(
      lat: 31.52,
      lng: 74.35,
      accuracy: 10,
      time: DateTime(2026, 10, 29, 8, 1),
    );

    expect(reads, 2);
  });
}
