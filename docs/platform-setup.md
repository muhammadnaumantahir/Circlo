# Platform setup for location sharing

`flutter create` generates `android/`, `ios/`, and `web/` inside `app/`. Then run `python3 tools/apply_platform_config.py` from the repository root. The helper is idempotent/best-effort, but still needs a local generated-project build and real-device verification.

## Shared build versions

- Flutter SDK: **3.47.2**, pinned once in the project-root `app/.fvmrc`; GitHub Actions and the Cloudflare build script read that pin.
- Android Gradle Plugin: **9.4.0**.
- Gradle wrapper: **9.8.0**.
- Kotlin Gradle plugin: **2.4.10**.
- Java/Kotlin target: **17**.
- Google Services Gradle plugin: **4.5.0** when its plugin declaration is present.

The native Android/Gradle files are generated locally rather than committed in this repository. The helper normalizes generated Gradle settings and wrapper to the toolchain versions above; it does not replace an Android build or emulator test. The app release version in `app/pubspec.yaml` remains Circlo-specific and must not be copied from FinMate, Stockly, or Imaanly.

## Android

In `app/android/app/src/main/AndroidManifest.xml`, before `<application>`, include `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, and `POST_NOTIFICATIONS`. Set `minSdk` to **23** (Firebase). Background sharing relies on the geolocator foreground service, which shows a persistent notification (FR-037). Some phone makers (Samsung, Xiaomi, etc.) kill background apps; users may have to exclude Circlo from battery optimisation (to be documented after real-device tests).

## iOS

In `app/ios/Runner/Info.plist`, add `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `UIBackgroundModes` → `location`. Building and distributing needs macOS and, for devices other than your own, a paid Apple Developer account (outside the $0 budget).

## Web

Location works only while the tab is open; HTTPS (or localhost) is required by browsers. Cloudflare Pages uses `bash build-cloudflare.sh`; the script verifies the Flutter SDK version against `app/.fvmrc` and outputs to repository-root `build/web`.

## Maps

Set `MAP_TILE_URL` / `MAP_ATTRIBUTION` (`--dart-define`) to a provider whose free-tier terms allow this app before any public release (ADR-0004).

## Verification status

Nothing here has been run on a real device. Required before claiming background sharing works (ADR-0003): ≥2 Android phones (including one Samsung/Xiaomi) and ≥1 iPhone: screen locked 30 minutes, app swiped away, battery saver on, airplane-mode recovery, permission denied/revoked mid-session.
