# Platform setup for location sharing

`flutter create` generates `android/`, `ios/`, `web/`. Then run `python3 tools/apply_platform_config.py` (best effort, **not yet verified**) or apply these changes by hand.

**Android** (`app/android/app/src/main/AndroidManifest.xml`, before `<application>`):
`INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`. Set `minSdk` to **23** (Firebase). Background sharing relies on the geolocator foreground service, which shows a persistent notification (FR-037). Some phone makers (Samsung, Xiaomi, etc.) kill background apps: users may have to exclude Circlo from battery optimisation (to be documented after real-device tests).

**iOS** (`app/ios/Runner/Info.plist`): `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes` → `location`. Building and distributing needs macOS and, for devices other than your own, a paid Apple Developer account (outside the $0 budget).

**Web:** location works only while the tab is open; HTTPS (or localhost) is required by browsers.

**Maps:** set `MAP_TILE_URL` / `MAP_ATTRIBUTION` (`--dart-define`) to a provider whose free-tier terms allow this app before any public release (ADR-0004).

## Verification status
Nothing here has been run on a real device. Required before claiming background sharing works (ADR-0003): ≥2 Android phones (incl. one Samsung/Xiaomi) and ≥1 iPhone: screen locked 30 min, app swiped away, battery saver on, airplane-mode recovery, permission denied/revoked mid-session.
