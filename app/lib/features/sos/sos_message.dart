import '../location/location_models.dart';
import '../location/sharing_status.dart';

/// Builds a user-reviewed SOS message without inventing a current location.
///
/// A location is included only when location sharing is active and the last
/// shared fix is fresh. Approximate/Bubble pins are always explicitly labelled.
String buildSosMessage({
  required String displayName,
  required bool sharingActive,
  required MemberLocation? location,
  required DateTime now,
}) {
  final sender = displayName.trim().isEmpty ? 'A Circlo member' : displayName.trim();
  final updatedAt = location?.updatedAt;
  final hasFreshLocation = sharingActive &&
      location != null &&
      updatedAt != null &&
      isLocationFixFresh(capturedAt: updatedAt, now: now);

  if (!hasFreshLocation) {
    return 'SOS from $sender: I need help. Circlo does not have a fresh shared location to include. Please contact me directly.';
  }

  final current = location!;
  final coordinates =
      current.lat.toStringAsFixed(6) + ',' + current.lng.toStringAsFixed(6);
  final mapLink = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': coordinates,
  }).toString();
  final age = formatAgo(updatedAt, now);

  if (current.approximate) {
    return 'SOS from $sender: I need help. My last shared location is an APPROXIMATE map pin (not my exact GPS location): $mapLink (updated $age). Please call me to confirm where I am.';
  }

  return 'SOS from $sender: I need help. My last shared location: $mapLink (updated $age). This may not be my exact current position. Please call me to confirm where I am.';
}
