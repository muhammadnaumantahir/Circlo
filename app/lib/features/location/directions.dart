import 'package:url_launcher/url_launcher.dart';

/// Opens the device's maps app (or the browser) with directions to a point. Free: no API key and
/// no in-app routing (FR-072).
Uri directionsUri(double lat, double lng) => Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
    });

Future<bool> launchDirections(double lat, double lng) =>
    launchUrl(directionsUri(lat, lng), mode: LaunchMode.externalApplication);
