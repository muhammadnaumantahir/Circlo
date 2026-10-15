import 'dart:convert';

import 'package:circlo/features/history/history_models.dart';
import 'package:circlo/features/location/directions.dart';
import 'package:circlo/features/profile/data_export.dart';
import 'package:circlo/features/profile/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directionsUri targets the destination without any API key', () {
    final u = directionsUri(31.5204, 74.3587);
    expect(u.host, 'www.google.com');
    expect(u.queryParameters['destination'], '31.520400,74.358700');
    expect(u.queryParameters['api'], '1');
    expect(u.toString().toLowerCase().contains('key'), isFalse);
  });

  test('export contains own data only and is valid JSON', () {
    final json = buildExportJson(
      exportedAt: DateTime.utc(2026, 10, 14),
      email: 'a@b.co',
      profile: const UserProfile(uid: 'u', displayName: 'Ali', birthYear: 1990, phone: '+923001234567', keepHistory: true, retentionDays: 30),
      circles: [
        {'name': 'Family', 'role': 'owner', 'sharingLocation': true, 'sharingHistory': false},
      ],
      placeAlerts: [
        {'circleId': 'c', 'placeId': 'p', 'arrive': true, 'leave': true, 'allMembers': true},
      ],
      history: [
        DayTrack(
          day: '20261013',
          tzOffsetMin: 300,
          visits: [Visit(name: 'Home', lat: 1, lng: 2, arrivedAt: 10, leftAt: 20)],
          route: const [TrackPoint(lat: 1, lng: 2, t: 10)],
        ),
      ],
    );
    final d = jsonDecode(json) as Map<String, dynamic>;
    expect(d['account']['email'], 'a@b.co');
    expect(d['account']['phone'], '+923001234567');
    expect(d['circles'], hasLength(1));
    expect(d['travelHistory'][0]['visits'][0]['name'], 'Home');
    expect(json.contains('uid'), isFalse); // no internal ids of the account
  });
}
