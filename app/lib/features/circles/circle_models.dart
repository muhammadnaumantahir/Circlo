import 'package:cloud_firestore/cloud_firestore.dart';

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
        name: data['name'] is String ? data['name'] as String : '',
        ownerUid: data['ownerUid'] is String ? data['ownerUid'] as String : '',
        joinCode: data['joinCode'] is String ? data['joinCode'] as String : '',
        requiresApproval: data['requiresApproval'] == true,
      );
}

/// A phone number a member has explicitly chosen to share with this circle.
class SharedContact {
  const SharedContact({required this.uid, required this.phone});

  final String uid;
  final String phone;

  static SharedContact? tryFromMap(String uid, Map<String, dynamic> data) {
    final phone = data['phone'];
    if (data['uid'] != uid || data['sharePhone'] != true || phone is! String) return null;
    if (!RegExp(r'^[+][1-9][0-9]{6,14}$').hasMatch(phone)) return null;
    return SharedContact(uid: uid, phone: phone);
  }
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
        displayName: data['displayName'] is String ? data['displayName'] as String : 'Member',
        role: data['role'] is String ? data['role'] as String : 'member',
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
    this.createdAt,
  });

  final String circleId;
  final String uid;
  final String displayName;
  final String joinCode;
  final bool approved;
  final DateTime? createdAt;

  factory JoinRequest.fromMap(String circleId, Map<String, dynamic> d) => JoinRequest(
        circleId: circleId,
        uid: d['uid'] is String ? d['uid'] as String : '',
        displayName: d['displayName'] is String ? d['displayName'] as String : 'Someone',
        joinCode: d['joinCode'] is String ? d['joinCode'] as String : '',
        approved: d['status'] == 'approved',
        createdAt: d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null,
      );
}

/// Result of entering a join code: either you are in, or a request was sent to the owner.
class JoinOutcome {
  const JoinOutcome({required this.circleId, required this.requested});
  final String circleId;
  final bool requested;
}
