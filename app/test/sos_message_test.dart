import 'package:circlo/features/location/location_models.dart';
import 'package:circlo/features/sos/sos_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);

  MemberLocation location({
    DateTime? updatedAt,
    double lat = 31.5204,
    double lng = 74.3587,
    double? accuracy,
    bool approximate = false,
  }) =>
      MemberLocation(
        uid: 'self',
        lat: lat,
        lng: lng,
        accuracy: accuracy ?? (approximate ? 1800 : 25),
        updatedAt: updatedAt ?? now.subtract(const Duration(minutes: 2)),
        approximate: approximate,
      );

  test('includes a fresh shared map link and labels it as last shared, not guaranteed current', () {
    final message = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(),
      now: now,
    );

    expect(message, contains('SOS from Nauman'));
    expect(message, contains('www.google.com/maps/search/'));
    expect(message, contains('31.520400'));
    expect(message, contains('74.358700'));
    expect(message, contains('updated 2 min ago'));
    expect(message, contains('may not be my exact current position'));
  });

  test('labels an approximate Bubble location and never calls it exact GPS', () {
    final message = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(approximate: true),
      now: now,
    );

    expect(message, contains('APPROXIMATE map pin'));
    expect(message, contains('not my exact GPS location'));
    expect(message, contains('www.google.com/maps/search/'));
  });

  test('does not include coordinates when sharing is paused or stopped, even if a fix is fresh', () {
    final message = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: false,
      location: location(),
      now: now,
    );

    expect(message, contains('does not have a fresh shared location'));
    expect(message, isNot(contains('www.google.com/maps/search/')));
    expect(message, isNot(contains('31.5204')));
  });

  test('does not include a stale location', () {
    final message = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(updatedAt: now.subtract(const Duration(hours: 1))),
      now: now,
    );

    expect(message, contains('does not have a fresh shared location'));
    expect(message, isNot(contains('www.google.com/maps/search/')));
    expect(message, isNot(contains('31.5204')));
  });

  test('does not include stale or implausibly future-dated coordinates', () {
    final stale = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(updatedAt: now.subtract(const Duration(minutes: 11))),
      now: now,
    );
    final future = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(updatedAt: now.add(const Duration(minutes: 3))),
      now: now,
    );

    for (final message in [stale, future]) {
      expect(message, contains('does not have a fresh shared location'));
      expect(message, isNot(contains('www.google.com/maps/search/')));
    }
  });

  test('freshness boundary accepts exactly ten minutes and rejects older fixes', () {
    final atLimit = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(updatedAt: now.subtract(const Duration(minutes: 10))),
      now: now,
    );
    final justTooOld = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(updatedAt: now.subtract(const Duration(minutes: 10, seconds: 1))),
      now: now,
    );

    expect(atLimit, contains('www.google.com/maps/search/'));
    expect(justTooOld, isNot(contains('www.google.com/maps/search/')));
  });

  test('freshness boundary tolerates two minutes of future clock skew only', () {
    final atLimit = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(updatedAt: now.add(const Duration(minutes: 2))),
      now: now,
    );
    final justTooFarAhead = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: location(updatedAt: now.add(const Duration(minutes: 2, seconds: 1))),
      now: now,
    );

    expect(atLimit, contains('www.google.com/maps/search/'));
    expect(justTooFarAhead, isNot(contains('www.google.com/maps/search/')));
  });

  test('omits a map link when coordinates or accuracy are invalid', () {
    final invalidLocations = [
      location(lat: 91),
      location(lat: -91),
      location(lng: 181),
      location(lng: -181),
      location(lat: double.nan),
      location(lng: double.infinity),
      location(accuracy: -1),
      location(accuracy: double.nan),
      location(accuracy: double.infinity),
    ];

    for (final invalidLocation in invalidLocations) {
      final message = buildSosMessage(
        displayName: 'Nauman',
        sharingActive: true,
        location: invalidLocation,
        now: now,
      );

      expect(message, contains('does not have a fresh shared location'));
      expect(message, isNot(contains('www.google.com/maps/search/')));
    }
  });

  test('omits a map link when the shared location has no timestamp', () {
    final missingTimestamp = MemberLocation(
      uid: 'self',
      lat: 31.5204,
      lng: 74.3587,
      accuracy: 25,
      updatedAt: null,
    );

    final message = buildSosMessage(
      displayName: 'Nauman',
      sharingActive: true,
      location: missingTimestamp,
      now: now,
    );

    expect(message, contains('does not have a fresh shared location'));
    expect(message, isNot(contains('www.google.com/maps/search/')));
  });

  test('uses a safe generic sender name when the profile name is blank', () {
    final message = buildSosMessage(
      displayName: '  ',
      sharingActive: false,
      location: null,
      now: now,
    );

    expect(message, startsWith('SOS from A Circlo member'));
  });
}
