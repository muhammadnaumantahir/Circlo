import 'package:cloud_firestore/cloud_firestore.dart';

/// Membership/sharing activity that other members see in their notification list.
/// Written in the same batch as the change it describes (firestore.rules checks that).
enum ActivityType { joined, left, removed, sharingStarted, sharingStopped }

String activityTypeName(ActivityType t) {
  switch (t) {
    case ActivityType.joined:
      return 'joined';
    case ActivityType.left:
      return 'left';
    case ActivityType.removed:
      return 'removed';
    case ActivityType.sharingStarted:
      return 'sharing_started';
    case ActivityType.sharingStopped:
      return 'sharing_stopped';
  }
}

ActivityType? activityTypeFromName(String? n) {
  for (final t in ActivityType.values) {
    if (activityTypeName(t) == n) return t;
  }
  return null;
}

Map<String, dynamic> activityDoc({
  required ActivityType type,
  required String actorUid,
  required String actorName,
  String? subjectUid,
  String? subjectName,
}) =>
    {
      'type': activityTypeName(type),
      'actorUid': actorUid,
      'actorName': actorName,
      if (subjectUid != null) 'subjectUid': subjectUid,
      if (subjectName != null) 'subjectName': subjectName,
      'occurredAt': FieldValue.serverTimestamp(),
    };

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.circleId,
    required this.type,
    required this.actorUid,
    required this.actorName,
    this.subjectName,
    required this.occurredAt,
  });

  final String id;
  final String circleId;
  final ActivityType type;
  final String actorUid;
  final String actorName;
  final String? subjectName;
  final DateTime? occurredAt;

  static ActivityEvent? fromMap(String circleId, String id, Map<String, dynamic> d) {
    final t = activityTypeFromName(d['type'] as String?);
    if (t == null) return null;
    return ActivityEvent(
      id: id,
      circleId: circleId,
      type: t,
      actorUid: (d['actorUid'] as String?) ?? '',
      actorName: (d['actorName'] as String?) ?? 'Someone',
      subjectName: d['subjectName'] as String?,
      occurredAt: (d['occurredAt'] as Timestamp?)?.toDate(),
    );
  }

  String get text {
    switch (type) {
      case ActivityType.joined:
        return '$actorName joined the circle';
      case ActivityType.left:
        return '$actorName left the circle';
      case ActivityType.removed:
        return '${subjectName ?? 'A member'} was removed from the circle';
      case ActivityType.sharingStarted:
        return '$actorName started sharing their location';
      case ActivityType.sharingStopped:
        return '$actorName stopped sharing their location';
    }
  }
}
