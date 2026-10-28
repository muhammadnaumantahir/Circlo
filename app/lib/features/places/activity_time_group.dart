/// Groups activity timestamps by the user's local calendar date.
String activityTimeGroupLabel(DateTime timestamp, {required DateTime now}) {
  final localTimestamp = timestamp.toLocal();
  final localNow = now.toLocal();

  // Use UTC calendar-day boundaries so daylight-saving transitions do not turn
  // a local day into a 23- or 25-hour duration.
  final eventDay = DateTime.utc(localTimestamp.year, localTimestamp.month, localTimestamp.day);
  final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final daysAgo = today.difference(eventDay).inDays;

  if (daysAgo < 0) return 'Upcoming';
  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo < 7) return 'This week';
  return 'Earlier';
}
