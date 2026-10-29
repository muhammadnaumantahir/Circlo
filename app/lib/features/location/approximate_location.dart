/// Grid spacing for the opt-in Approximate Location (Bubble) map pin.
/// A snapped point can be roughly 1–1.6 km from the device's true coordinates.
const double kApproximateGridDegrees = 0.02;

/// Advertised uncertainty floor for a grid-snapped map point.
const double kApproximateAccuracyFloorM = 1700;

/// Coarse coordinates to share instead of precise GPS coordinates.
class ApproximateCoordinates {
  const ApproximateCoordinates({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Snaps coordinates to a stable grid cell center. Call only after validating the GPS sample.
/// The original lat/lng must never be included in the same shared location document.
ApproximateCoordinates approximateCoordinatesFor(double lat, double lng) {
  if (!lat.isFinite || !lng.isFinite ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw ArgumentError('Coordinates must be finite and within valid GPS ranges.');
  }

  double snap(double value, double min, double max) =>
      ((value / kApproximateGridDegrees).round() * kApproximateGridDegrees)
          .clamp(min, max)
          .toDouble();

  return ApproximateCoordinates(
    lat: snap(lat, -90, 90),
    lng: snap(lng, -180, 180),
  );
}
