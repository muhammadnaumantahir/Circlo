import 'package:cloud_firestore/cloud_firestore.dart';

/// Turns the underlying Firestore failure into an actionable Circle-list message.
///
/// Keep the Firebase error code visible: it distinguishes Rules deployment,
/// index configuration and connectivity failures without exposing raw stack traces.
String circlesLoadErrorMessage(Object error) {
  if (error is! FirebaseException) {
    return 'An unexpected error occurred while loading circles '
        '(${error.runtimeType}): $error';
  }

  final details = error.message?.trim();
  final detailSuffix = details == null || details.isEmpty ? '' : '\\n$details';

  switch (error.code) {
    case 'permission-denied':
      return 'Firestore denied the circle membership query. Deploy the latest '
          'firebase/firestore.rules to the Firebase project used by this app. '
          '(permission-denied)$detailSuffix';
    case 'failed-precondition':
      return 'Firestore rejected the circle membership query. Deploy '
          'firebase/firestore.indexes.json and check Firebase Console for the '
          'members.uid collection-group index. (failed-precondition)$detailSuffix';
    case 'unauthenticated':
      return 'Your Firebase sign-in session is no longer valid. Sign in again. '
          '(unauthenticated)$detailSuffix';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'Firebase is temporarily unavailable. Check your connection and '
          'retry. (${error.code})$detailSuffix';
    default:
      return 'Firebase could not load your circles (${error.code}). '
          'Check the Firebase project configuration and try again.$detailSuffix';
  }
}
