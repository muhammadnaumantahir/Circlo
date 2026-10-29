import 'dart:convert';

import '../history/history_models.dart';
import 'profile_models.dart';

/// Builds a readable JSON export of the user's own data (FR-093). Pure function so it can be tested.
/// It contains only data the user already owns; it never includes other people's data or tokens.
String buildExportJson({
  required DateTime exportedAt,
  required String email,
  required UserProfile profile,
  required List<Map<String, dynamic>> circles,
  required List<Map<String, dynamic>> placeAlerts,
  required List<DayTrack> history,
}) {
  final data = <String, dynamic>{
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'account': {
      'email': email,
      'displayName': profile.displayName,
      if (profile.phone != null) 'phone': profile.phone,
      'birthYear': profile.birthYear,
    },
    'settings': {
      'keepTravelHistory': profile.keepHistory,
      'historyRetentionDays': profile.retentionDays,
      'placeSuggestionsEnabled': profile.placeSuggestionsEnabled,
      'notificationsOff': profile.notifOff,
      'mutedCircles': profile.notifMuted,
    },
    'circles': circles,
    'placeAlerts': placeAlerts,
    'travelHistory': [
      for (final d in history)
        {
          'day': d.day,
          'utcOffsetMinutes': d.tzOffsetMin,
          'visits': [for (final v in d.visits) v.toMap()],
          'route': [for (final p in d.route) p.toMap()],
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}
