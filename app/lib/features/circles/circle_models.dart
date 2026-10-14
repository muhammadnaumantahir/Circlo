class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.joinCode,
    this.requiresApproval = false,
  });

  final String id;
  final String name;
  final String ownerUid;
  final String joinCode;
  final bool requiresApproval;

  factory Circle.fromMap(String id, Map<String, dynamic> data) => Circle(
        id: id,
        name: (data['name'] as String?) ?? '',
        ownerUid: (data['ownerUid'] as String?) ?? '',
        joinCode: (data['joinCode'] as String?) ?? '',
        requiresApproval: data['requiresApproval'] == true,
      );
}

class Member {
  const Member({
    required this.uid,
    required this.displayName,
    required this.role,
    this.sharesLocation = false,
    this.paused = false,
    this.historyShared = false,
  });

  final String uid;
  final String displayName;
  final String role;
  final bool sharesLocation;
  final bool paused;
  final bool historyShared;

  bool get isOwner => role == 'owner';

  factory Member.fromMap(String uid, Map<String, dynamic> data) => Member(
        uid: uid,
        displayName: (data['displayName'] as String?) ?? 'Member',
        role: (data['role'] as String?) ?? 'member',
        sharesLocation: data['sharesLocation'] == true,
        paused: data['paused'] == true,
        historyShared: data['historyShared'] == true,
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

/// A request to join a circle that requires the owner's approval.
class JoinRequest {
  const JoinRequest({
    required this.circleId,
    required this.uid,
    required this.displayName,
    required this.joinCode,
    required this.approved,
  });

  final String circleId;
  final String uid;
  final String displayName;
  final String joinCode;
  final bool approved;

  factory JoinRequest.fromMap(String circleId, Map<String, dynamic> d) => JoinRequest(
        circleId: circleId,
        uid: (d['uid'] as String?) ?? '',
        displayName: (d['displayName'] as String?) ?? 'Someone',
        joinCode: (d['joinCode'] as String?) ?? '',
        approved: d['status'] == 'approved',
      );
}

/// Result of entering a join code: either you are in, or a request was sent to the owner.
class JoinOutcome {
  const JoinOutcome({required this.circleId, required this.requested});
  final String circleId;
  final bool requested;
}
