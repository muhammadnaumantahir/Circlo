class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.birthYear,
    this.phone,
  });

  final String uid;
  final String displayName;
  final int birthYear;
  final String? phone;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) =>
      UserProfile(
        uid: uid,
        displayName: (data['displayName'] as String?) ?? '',
        birthYear: (data['birthYear'] as num?)?.toInt() ?? 0,
        phone: data['phone'] as String?,
      );
}
