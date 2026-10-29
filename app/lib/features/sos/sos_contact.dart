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
