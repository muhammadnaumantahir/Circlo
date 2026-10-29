import 'package:url_launcher/url_launcher.dart';

/// Travel modes that Google Maps URLs support. ETA and route calculation remain external,
/// avoiding a paid directions API and preventing Circlo from showing an invented estimate.
enum TravelMode {
  driving('driving', 'Driving', 'Road route and ETA from Google Maps'),
  walking('walking', 'Walking', 'Walking route and ETA from Google Maps'),
  cycling('bicycling', 'Cycling', 'Cycling route where available'),
  transit('transit', 'Public transport', 'Transit options where available');

  const TravelMode(this.queryValue, this.label, this.description);

  final String queryValue;
  final String label;
  final String description;
}

/// Opens Google Maps (app or browser) with the selected route mode. No API key is required.
/// When origin is omitted Google Maps can use the device's current location.
Uri directionsUri(
  double lat,
  double lng, {
  TravelMode travelMode = TravelMode.driving,
}) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
      'travelmode': travelMode.queryValue,
    });

Future<bool> launchDirections(
  double lat,
  double lng, {
  TravelMode travelMode = TravelMode.driving,
}) =>
    launchUrl(
      directionsUri(lat, lng, travelMode: travelMode),
      mode: LaunchMode.externalApplication,
    );
