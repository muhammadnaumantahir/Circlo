import 'package:cloud_firestore/cloud_firestore.dart';

/// Membership, sharing and user-selected manual check-ins shown in the in-app feed.
/// Check-ins contain no GPS coordinates and are self-reported, not location-verified.
const Map<String, String> kCheckInStatuses = {
  'im_okay': "I'm okay",
  'arrived_safely': 'Arrived safely',
  'on_my_way': 'On my way',
  'running_late': 'Running late',
};

/// Curated, one-tap notes shared to a circle's in-app activity feed.
const Map<String, String> kQuickNotes = {
  '❤️': 'Love you',
  '👍': 'Got it',
  '🚗': 'On the road',
  '🏠': 'At home',
  '🙂': 'All good',
  '⏰': 'Be there soon',
  '👋': 'Hi there',
  '🙏': 'Thank you',
};

enum ActivityType { joined, left, removed, sharingStarted, sharingStopped, checkedIn, quickNote }

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
    case ActivityType.checkedIn:
      return 'checked_in';
    case ActivityType.quickNote:
      return 'quick_note';
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
  String? checkInStatus,
  String? checkInPlaceId,
  String? checkInPlaceName,
  String? quickNoteEmoji,
  String? quickNoteText,
}) =>
    {
      'type': activityTypeName(type),
      'actorUid': actorUid,
      'actorName': actorName,
      if (subjectUid != null) 'subjectUid': subjectUid,
      if (subjectName != null) 'subjectName': subjectName,
      if (checkInStatus != null) 'checkInStatus': checkInStatus,
      if (checkInPlaceId != null) 'checkInPlaceId': checkInPlaceId,
      if (checkInPlaceName != null) 'checkInPlaceName': checkInPlaceName,
      if (quickNoteEmoji != null) 'quickNoteEmoji': quickNoteEmoji,
      if (quickNoteText != null) 'quickNoteText': quickNoteText,
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
    this.checkInStatus,
    this.checkInPlaceId,
    this.checkInPlaceName,
    this.quickNoteEmoji,
    this.quickNoteText,
    required this.occurredAt,
  });

  final String id;
  final String circleId;
  final ActivityType type;
  final String actorUid;
  final String actorName;
  final String? subjectName;
  final String? checkInStatus;
  final String? checkInPlaceId;
  final String? checkInPlaceName;
  final String? quickNoteEmoji;
  final String? quickNoteText;
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
      checkInStatus: d['checkInStatus'] as String?,
      checkInPlaceId: d['checkInPlaceId'] as String?,
      checkInPlaceName: d['checkInPlaceName'] as String?,
      quickNoteEmoji: d['quickNoteEmoji'] as String?,
      quickNoteText: d['quickNoteText'] as String?,
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
      case ActivityType.checkedIn:
        return '$actorName shared a manual check-in: ${kCheckInStatuses[checkInStatus] ?? "I'm okay"}'
            '${checkInPlaceName?.isNotEmpty == true ? ' · at $checkInPlaceName' : ''}';
      case ActivityType.quickNote:
        return '$actorName sent a quick note: ${quickNoteEmoji ?? ''} ${quickNoteText ?? ''}'.trim();
    }
  }
}
