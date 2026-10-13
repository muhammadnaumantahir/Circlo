# Circlo

Private, consent-based location sharing for families and friends: circles, live map, place arrival/departure alerts, and travel history.

**Status:** Development started (Increment 1: accounts + circles). See [project-status.md](project-status.md) and [CHANGELOG.md](CHANGELOG.md). Not production-ready; location features are not built yet.

## Stack ($0 budget, no billing account)
Flutter (web, Android, iOS) · Firebase Authentication · Cloud Firestore · FCM (later). See [architecture.md](architecture.md).

## Prerequisites
Flutter (stable), Node.js 22+, Java 21+ (for the Firestore emulator), a free Firebase project on the **Spark** plan with Email/Password sign-in enabled and Firestore created.

## Setup
```bash
# 1. Generate platform folders (not committed yet)
cd app
flutter create --org com.circlo --project-name circlo --platforms=android,ios,web .
git checkout -- pubspec.yaml analysis_options.yaml lib test   # keep our files
rm -f test/widget_test.dart                                   # generated sample test, not ours
flutter pub get

# 2. Configure Firebase at build time (see .env.example; copy values to a git-ignored env.json)
flutter run -d chrome --dart-define-from-file=env.json

# 3. Deploy rules to your Firebase project (from repo root's firebase/ folder)
cd ../firebase && npm ci && npx firebase deploy --only firestore:rules,firestore:indexes --project <your-project-id>
```
Local development without a cloud project: `cd firebase && npx firebase emulators:start --only auth,firestore --project demo-circlo`, then run the app with `USE_FIREBASE_EMULATOR=true`.

## Test
```bash
cd app && flutter analyze && flutter test
cd firebase && npm test            # Firestore rules tests (emulator)
```

## Documentation
- [PROJECT_BRIEF.md](PROJECT_BRIEF.md) · [requirements.md](requirements.md) · [architecture.md](architecture.md) · [AGENTS.md](AGENTS.md)
- Design: [design-system](design/design-system.md), [screens](design/screen-specification.md), [prompts](design/design-prompts.md), [user flows](docs/user-flows.md)
- Docs: [data model](docs/data-model.md), [security & privacy](docs/security-privacy.md), [review findings](docs/review-findings.md), [test plan](docs/test-plan.md), [traceability](docs/traceability.md), [risks](docs/risks.md), [roadmap](docs/roadmap.md), [decisions](docs/decisions/)
