import '../circles/circle_models.dart';

/// Filters shared phone records to current Circle members and excludes the signed-in user.
///
/// The caller must supply the circle-scoped shared-contact stream, which only
/// contains phone numbers shared with consent. This extra membership check keeps
/// stale contact records for removed members out of the SOS actions.
List<SharedContact> sosContactRecipients({
  required Iterable<SharedContact> sharedContacts,
  required Iterable<Member> circleMembers,
  required String? currentUid,
}) {
  // If authentication has not resolved, we cannot safely identify and exclude self.
  if (currentUid == null || currentUid.trim().isEmpty) {
    return const <SharedContact>[];
  }

  final membersByUid = {for (final member in circleMembers) member.uid: member};
  final validPhone = RegExp(r'^\+[1-9][0-9]{6,14}
      .where((contact) =>
          contact.uid != currentUid &&
          membersByUid.containsKey(contact.uid) &&
          validPhone.hasMatch(contact.phone))
      .toList()
    ..sort((a, b) => membersByUid[a.uid]!
        .displayName
        .toLowerCase()
        .compareTo(membersByUid[b.uid]!.displayName.toLowerCase()));

  return recipients;
}

/// Builds external phone-app links for an opted-in Circle member.
///
/// These URIs only open the dialer or a message composer. They do not place a
/// call or send a text from Circlo.
Uri sosCallUri(String phone) => Uri(scheme: 'tel', path: phone);

/// Opens the user's messaging app with a reviewable, unsent SOS draft.
Uri sosTextUri(String phone, String message) => Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
);

  final recipients = sharedContacts
      .where((contact) =>
          contact.uid != currentUid &&
          membersByUid.containsKey(contact.uid) &&
          validPhone.hasMatch(contact.phone))
      .toList()
    ..sort((a, b) => membersByUid[a.uid]!
        .displayName
        .toLowerCase()
        .compareTo(membersByUid[b.uid]!.displayName.toLowerCase()));

  return recipients;
}

/// Builds external phone-app links for an opted-in Circle member.
///
/// These URIs only open the dialer or a message composer. They do not place a
/// call or send a text from Circlo.
Uri sosCallUri(String phone) => Uri(scheme: 'tel', path: phone);

/// Opens the user's messaging app with a reviewable, unsent SOS draft.
Uri sosTextUri(String phone, String message) => Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
