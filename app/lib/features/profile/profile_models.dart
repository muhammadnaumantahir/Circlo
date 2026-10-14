class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.birthYear,
    this.phone,
    this.keepHistory = false,
    this.retentionDays = 30,
  });

  final String uid;
  final String displayName;
  final int birthYear;
  final String? phone;
  final bool keepHistory; // record a private travel history while sharing is on
  final int retentionDays; // 7, 30 or 90

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) =>
      UserProfile(
        uid: uid,
        displayName: (data['displayName'] as String?) ?? '',
        birthYear: (data['birthYear'] as num?)?.toInt() ?? 0,
        phone: data['phone'] as String?,
        keepHistory: data['keepHistory'] == true,
        retentionDays: (data['retentionDays'] as num?)?.toInt() ?? 30,
      );
}
