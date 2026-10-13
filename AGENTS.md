# AGENTS.md — instructions for AI coding sessions on Circlo

Read before coding: `PROJECT_BRIEF.md`, `requirements.md`, `architecture.md`, `project-status.md`, `docs/review-findings.md`, `docs/data-model.md`, `docs/security-privacy.md`, applicable `design/*` and `docs/decisions/*`.

## Rules
1. **Approved requirements are the source of truth.** Work by requirement ID (FR-xxx / NFR-xxx) and its acceptance criteria. If documents conflict, say so and ask; do not silently pick one.
2. **Hard constraints:** $0 budget, no billing account, Firebase Auth + Cloud Firestore + FCM only. **Never** add Cloud Functions, Cloud Storage, paid APIs, or any paid service. **Never** put FCM service-account keys, tokens, or other secrets in the app or repo.
3. **Security is enforced by `firebase/firestore.rules`, not by the client.** Every new collection/field needs rules + emulator tests in `firebase/tests/` *in the same change*. Default deny. Check membership **and** the specific circle's sharing permission.
4. **Do not claim** remote push, scheduled cleanup, complete account deletion, or background-tracking reliability until proven (see `docs/review-findings.md` P0/P1).
5. **Small, reviewable increments.** Inspect existing code first. No unrelated refactors, no unnecessary dependencies, no unapproved features (put ideas in `docs/roadmap.md`).
6. **UI:** implement loading, empty, error, offline and permission-denied states; accessible labels; no dead buttons or fake data. Only show tabs/features that work.
7. **Tests with code.** Run `flutter analyze`, `flutter test` (in `app/`) and `npm test` (in `firebase/`). Report results honestly: Passed / Failed / Blocked / Not run, with the command.
8. **Docs stay accurate.** Update `project-status.md`, `docs/traceability.md`, `docs/test-plan.md`, `CHANGELOG.md` when behaviour changes.
9. **No push, deploy, or destructive operation without explicit owner approval.**
10. Minimum age (13) lives in both `app/lib/core/validators.dart` and `firebase/firestore.rules`; the join-code alphabet/length in `app/lib/core/join_code.dart` and the rules. Change them together.

## Layout
`app/` Flutter (web/Android/iOS) · `firebase/` rules, indexes, rules tests · `docs/`, `design/` documentation · `docs/ci/ci.yml` (copy to `.github/workflows/ci.yml` to enable).
Platform folders (`android/`, `ios/`, `web/`) are generated with `flutter create` (see README); do not hand-write them.

## Local commands
```
cd firebase && npm ci && npm test          # needs Java 21+; downloads the Firestore emulator
cd app && flutter create --org com.circlo --project-name circlo --platforms=android,ios,web . && flutter pub get && flutter analyze && flutter test
```
