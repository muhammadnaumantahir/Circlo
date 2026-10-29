import '../location/location_models.dart';
import '../location/sharing_status.dart';

/// Returns whether an SOS may safely include the last shared location.
///
/// Sharing must be active, the coordinates/accuracy must be valid, and the
/// saved fix must be recent and not materially future-dated. Keep the screen's
/// status label and outgoing message on this shared predicate so they cannot
/// disagree.
bool hasFreshSosLocation({
  required bool sharingActive,
  required MemberLocation? location,
  required DateTime now,
}) {
  final updatedAt = location?.updatedAt;
  return sharingActive &&
      location != null &&
      isValidLocationSample(
        lat: location.lat,
        lng: location.lng,
        accuracy: location.accuracy,
      ) &&
      updatedAt != null &&
      isLocationFixFresh(capturedAt: updatedAt, now: now);
}

/// Builds a user-reviewed SOS message without inventing a current location.
///
/// A location is included only when sharing is active and the last shared fix
/// is fresh and has valid coordinates. Approximate/Bubble pins are labelled.
String buildSosMessage({
  required String displayName,
  required bool sharingActive,
  required MemberLocation? location,
  required DateTime now,
}) {
  final sender = displayName.trim().isEmpty ? 'A Circlo member' : displayName.trim();
  final updatedAt = location?.updatedAt;
  final hasFreshLocation = hasFreshSosLocation(
    sharingActive: sharingActive,
    location: location,
    now: now,
  );

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
