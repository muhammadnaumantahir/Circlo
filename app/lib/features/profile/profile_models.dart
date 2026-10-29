import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.birthYear,
    this.phone,
    this.keepHistory = false,
    this.retentionDays = 30,
    this.placeSuggestionsEnabled = false,
    this.notifOff = const <String>[],
    this.notifMuted = const <String>[],
    this.notifSeenAt,
  });

  final String uid;
  final String displayName;
  final int birthYear;
  final String? phone;
  final bool keepHistory; // record a private travel history while sharing is on
  final int retentionDays; // 7, 30 or 90
  /// Separate opt-in for analyzing private history to suggest saved places.
  final bool placeSuggestionsEnabled;
  final List<String> notifOff; // notification kinds the user switched off
  final List<String> notifMuted; // circle ids the user muted
  final DateTime? notifSeenAt; // when the notifications list was last opened

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) =>
      UserProfile(
        uid: uid,
        displayName: (data['displayName'] as String?) ?? '',
        birthYear: (data['birthYear'] as num?)?.toInt() ?? 0,
        phone: data['phone'] as String?,
        keepHistory: data['keepHistory'] == true,
        retentionDays: (data['retentionDays'] as num?)?.toInt() ?? 30,
        placeSuggestionsEnabled: data['placeSuggestionsEnabled'] == true && data['keepHistory'] == true,
        notifOff: [for (final x in (data['notifOff'] as List? ?? const [])) x.toString()],
        notifMuted: [for (final x in (data['notifMuted'] as List? ?? const [])) x.toString()],
        notifSeenAt: (data['notifSeenAt'] as Timestamp?)?.toDate(),
      );
}
