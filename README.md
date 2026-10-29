# Circlo

Private, consent-based location sharing for families and friends: circles with shareable QR invites, live map, place arrival/departure alerts, and travel history.

**Status:** Development / hardening. Account, circle, location-sharing, saved-place, history, and in-app notification flows exist in source, but the app is not release-verified. See the [canonical feature status and cross-chat handover](docs/feature-status.md), [Life360-inspired roadmap](docs/life360-feature-roadmap.md), [project-status.md](project-status.md), [CHANGELOG.md](CHANGELOG.md), and the [feature audit](docs/feature-audit-2026-10-28.md).

## Stack ($0 budget, no billing account)
Flutter (web, Android, iOS) · Firebase Authentication · Cloud Firestore · FCM (later). See [architecture.md](architecture.md).

## Prerequisites
Flutter (stable), Node.js 22+, Java 21+ (for the Firestore emulator), a free Firebase project on the **Spark** plan with Email/Password sign-in enabled and Firestore created.

## Setup
```bash
# 1. Generate platform folders (not committed yet)
cd app
flutter create --org com.circlo --project-name app --platforms=android,ios,web .
git checkout -- pubspec.yaml analysis_options.yaml lib test   # keep our files
rm -f test/widget_test.dart                                   # generated sample test, not ours
flutter pub get

python3 ../tools/apply_platform_config.py                      # IDs, location permissions and Google OAuth (see docs/platform-setup.md)

# 2. Configure Firebase at build time (see .env.example; copy values to a git-ignored env.json)
flutter run -d chrome --dart-define-from-file=env.json

# 3. Deploy rules to your Firebase project (from repo root's firebase/ folder)
cd ../firebase && npm ci && npx firebase deploy --only firestore:rules,firestore:indexes --project <your-project-id>
```
Email verification: with the Auth emulator, open `http://localhost:9099/emulator/v1/projects/demo-circlo/oobCodes` to find the verification link (the emulator UI is disabled in `firebase.json`).

Local development without a cloud project: `cd firebase && npx firebase emulators:start --only auth,firestore --project demo-circlo`, then run the app with `USE_FIREBASE_EMULATOR=true`.

## Test
```bash
cd app && flutter analyze && flutter test
cd firebase && npm test            # Firestore rules tests (emulator)
```

## Documentation
- [PROJECT_BRIEF.md](PROJECT_BRIEF.md) · [requirements.md](requirements.md) · [architecture.md](architecture.md) · [AGENTS.md](AGENTS.md) · [Google Sign-In setup](docs/google-signin-setup.md)
- Design: [design-system](design/design-system.md), [screens](design/screen-specification.md), [prompts](design/design-prompts.md), [user flows](docs/user-flows.md)
- Docs: [data model](docs/data-model.md), [security & privacy](docs/security-privacy.md), [feature audit and release blockers](docs/feature-audit-2026-10-28.md), [review findings](docs/review-findings.md), [test plan](docs/test-plan.md), [traceability](docs/traceability.md), [risks](docs/risks.md), [roadmap](docs/roadmap.md), [decisions](docs/decisions/)
## Web deployment

Cloudflare Pages should use the repository root and these settings:

- **Build command:** `bash ./build-cloudflare.sh`
- **Build output directory:** `build/web`

The script builds the Flutter project in `app/` and copies the web output to the repository-root `build/web`, keeping deployment settings consistent with FinMate and Stockly. Pushes to `main` trigger the Cloudflare Pages deployment.


### Cloudflare Pages Firebase web variables

In **Cloudflare Pages → Circlo → Settings → Environment variables**, add these for the **Production** environment (and Preview too if you test preview deployments):

- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_APP_ID_WEB`

Copy the values from **Firebase Console → Project settings → General → Your apps → Web app → SDK setup and configuration**. These are Firebase client configuration values, not service-account credentials. The build script passes them into Flutter via `--dart-define`; without them the deployed app displays the Firebase setup screen. Never add service-account JSON or FCM server credentials to Cloudflare or the Flutter app.


## Native Android and iOS Firebase setup

- **Android package name and iOS bundle ID:** `com.circlo.app`. The Setup command uses `--project-name app` so Flutter generates this native identifier.
- Firebase client options in `app/lib/core/firebase_options.dart` now match the registered Web, Android and iOS apps in project `circlo-1dbda`.
- The repository does not commit generated `app/android/` or `app/ios/` platform folders yet. Generate them locally using the Setup command above before editing their Gradle/Xcode settings.
- After Android platform generation, place the downloaded `google-services.json` at `app/android/app/google-services.json`. After iOS platform generation, place `GoogleService-Info.plist` at `app/ios/Runner/GoogleService-Info.plist`. Both files are excluded by `.gitignore`; keep them local and do not add them to commits.
- Circlo uses FlutterFire packages (`firebase_core`, `firebase_auth`, `cloud_firestore`). Do not add native Firebase BoM dependencies or Firebase Analytics manually; they are not needed for the current Flutter code.
- Google sign-in is implemented using Firebase Authentication for web, Android and iOS. Enable the Google provider, add authorized web domains and register native OAuth configuration before testing. See [Google Sign-In setup](docs/google-signin-setup.md). The platform helper applies Android Google Services configuration and iOS client IDs/callback URL scheme when the refreshed local Firebase config files are present.
- Building iOS requires macOS and Xcode; platform registration and editing these configuration files can be done from Windows.
