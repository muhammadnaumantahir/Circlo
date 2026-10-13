import 'package:geolocator/geolocator.dart';

/// What the app can currently do with the device location.
enum LocationAccess { serviceDisabled, denied, deniedForever, granted }

LocationAccess _fromPermission(LocationPermission p) {
  switch (p) {
    case LocationPermission.always:
    case LocationPermission.whileInUse:
      return LocationAccess.granted;
    case LocationPermission.deniedForever:
      return LocationAccess.deniedForever;
    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      return LocationAccess.denied;
  }
}

Future<LocationAccess> currentLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return LocationAccess.serviceDisabled;
  }
  return _fromPermission(await Geolocator.checkPermission());
}

/// Shows the OS permission prompt (only call after the user has seen our consent text).
Future<LocationAccess> requestLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return LocationAccess.serviceDisabled;
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) {
    p = await Geolocator.requestPermission();
  }
  return _fromPermission(p);
}

Future<void> openAppLocationSettings() => Geolocator.openAppSettings();
Future<void> openDeviceLocationSettings() => Geolocator.openLocationSettings();
