# Circlo version consistency

## Single Flutter SDK pin

The repository root `.fvmrc` is the single source of truth for Flutter SDK version **3.47.2**. The manual Flutter CI job reads the version from it before installing the SDK. `build-cloudflare.sh` reads the same file, only reuses a PATH SDK if it matches exactly, and replaces a mismatched or incomplete `/tmp/flutter` checkout. Both paths fail instead of silently building with a different SDK.

## Native Android versions

Circlo does not track generated `app/android/` or `app/ios/` folders. After `flutter create`, `python3 tools/apply_platform_config.py` applies the native project identifiers and location permissions. It now also normalizes generated Android Gradle settings to:

| Component | Version |
|---|---:|
| Flutter SDK | 3.47.2 |
| Android Gradle Plugin | 9.4.0 |
| Gradle wrapper | 9.8.0 |
| Kotlin Gradle plugin | 2.4.10 |
| Java/Kotlin target | 17 |
| Google Services Gradle plugin (when declared) | 4.5.0 |

The Android versions follow the common AGP, Gradle, Kotlin, and Java configuration inspected in FinMate, Stockly, and Imaanly; 4.5.0 is the current value shared by FinMate and Stockly for Google Services.

## App release version is separate

Circlo's `app/pubspec.yaml` stays at its own `version: 0.1.0+1) until a Circlo release is intentionally versioned. The semantic app version and build number should advance according to Circlo release changes; they should not be set equal to unrelated apps' release numbers.

## Validation

Static source updates were committed on the Circlo UI/audit branch. No Flutter build/analyze/test or generated Android Gradle build has been run in this environment, so compatibility with actual generated native files remains unverified.
