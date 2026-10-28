import 'package:circlo/features/location/sharing_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 13, 12, 0);

  group('deriveStatus', () {
    test('not sharing when the circle switch is off, regardless of old data', () {
      expect(
        deriveStatus(sharesLocation: false, paused: false, updatedAt: now, now: now),
        ShareStatus.notSharing,
      );
    });
    test('paused wins over fresh data', () {
      expect(
        deriveStatus(sharesLocation: true, paused: true, updatedAt: now, now: now),
        ShareStatus.paused,
      );
    });
    test('sharing when fresh, unavailable when stale or missing', () {
      expect(
        deriveStatus(sharesLocation: true, paused: false, updatedAt: now.subtract(const Duration(minutes: 9)), now: now),
        ShareStatus.sharing,
      );
      expect(
        deriveStatus(sharesLocation: true, paused: false, updatedAt: now.subtract(const Duration(minutes: 11)), now: now),
        ShareStatus.unavailable,
      );
      expect(
        deriveStatus(sharesLocation: true, paused: false, updatedAt: null, now: now),
        ShareStatus.unavailable,
      );
    });
  });

  group('isLocationFixFresh', () {
    test('accepts a current or recent fix', () {
      expect(isLocationFixFresh(capturedAt: now, now: now), isTrue);
      expect(
        isLocationFixFresh(capturedAt: now.subtract(const Duration(minutes: 9)), now: now),
        isTrue,
      );
    });

    test('rejects a stale fix and an implausibly future-dated fix', () {
      expect(
        isLocationFixFresh(capturedAt: now.subtract(const Duration(minutes: 11)), now: now),
        isFalse,
      );
      expect(
        isLocationFixFresh(capturedAt: now.add(const Duration(minutes: 3)), now: now),
        isFalse,
      );
    });

    test('allows a small device-clock skew', () {
      expect(
        isLocationFixFresh(capturedAt: now.add(const Duration(minutes: 1)), now: now),
        isTrue,
      );
    });
  });

  test('formatAgo', () {
    expect(formatAgo(null, now), 'never');
    expect(formatAgo(now.add(const Duration(minutes: 1)), now), 'just now');
    expect(formatAgo(now.add(const Duration(minutes: 3)), now), 'time unavailable');
    expect(formatAgo(now.subtract(const Duration(seconds: 20)), now), 'just now');
    expect(formatAgo(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
    expect(formatAgo(now.subtract(const Duration(hours: 3)), now), '3 h ago');
    expect(formatAgo(now.subtract(const Duration(days: 2)), now), '2 d ago');
  });

  test('statusLabel gives text for every status (never colour alone)', () {
    for (final s in ShareStatus.values) {
      expect(statusLabel(s), isNotEmpty);
    }
  });

  group('UploadThrottle', () {
    test('allows the first upload, blocks within the interval, allows after it', () {
      final t = UploadThrottle(minInterval: const Duration(seconds: 30));
      expect(t.allow(now), isTrue);
      expect(t.allow(now.add(const Duration(seconds: 10))), isFalse);
      expect(t.allow(now.add(const Duration(seconds: 30))), isTrue);
    });
    test('reset allows an immediate upload again', () {
      final t = UploadThrottle();
      expect(t.allow(now), isTrue);
      t.reset();
      expect(t.allow(now), isTrue);
    });
  });
}
