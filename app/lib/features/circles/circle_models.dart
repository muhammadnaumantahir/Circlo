class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.joinCode,
  });

  final String id;
  final String name;
  final String ownerUid;
  final String joinCode;

  factory Circle.fromMap(String id, Map<String, dynamic> data) => Circle(
        id: id,
        name: (data['name'] as String?) ?? '',
        ownerUid: (data['ownerUid'] as String?) ?? '',
        joinCode: (data['joinCode'] as String?) ?? '',
      );
}

class Member {
  const Member({
    required this.uid,
    required this.displayName,
    required this.role,
    this.sharesLocation = false,
    this.paused = false,
  });

  final String uid;
  final String displayName;
  final String role;
  final bool sharesLocation;
  final bool paused;

  bool get isOwner => role == 'owner';

  factory Member.fromMap(String uid, Map<String, dynamic> data) => Member(
        uid: uid,
        displayName: (data['displayName'] as String?) ?? 'Member',
        role: (data['role'] as String?) ?? 'member',
        sharesLocation: data['sharesLocation'] == true,
        paused: data['paused'] == true,
      );
}

enum JoinFailureKind { invalid, alreadyMember }

class JoinFailure implements Exception {
  const JoinFailure(this.kind);
  final JoinFailureKind kind;

  String get message => kind == JoinFailureKind.alreadyMember
      ? 'You are already in this circle.'
      : 'That code is not valid or has expired. Check it and try again.';

  @override
  String toString() => message;
}
