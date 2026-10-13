# Project Status

- **Current phase:** Phase 6 — Development, Increment 1 (accounts + circles).
- **Approved baseline:** v0.3 (Firebase-only). **Approval date: 2026-10-13** — owner instruction "I have updated the documents, read them and start the development".
- **Approval scope/interpretation:** start development with work that does not depend on the P0 trusted-server blocker. Remote cross-user push, scheduled cleanup, complete account deletion and server-dependent flows stay **deferred** until the owner chooses a no-cost trusted mechanism or formally accepts the reduced scope.
- **Scope decision (2026-10-13, owner):** accept a **smaller scope without the P0 server-dependent features**: no remote cross-user push notifications, no scheduled/automatic cleanup, no complete recursive account deletion guarantee, no server-side validation of events. Alerts and notices are therefore **in-app only** (visible when the app is open/synced) until a trusted no-cost mechanism is approved. Increment 2 (location sharing) proceeds on this basis.
- **Implementation code:** Increment 1 written (see below); not yet executed in the authoring environment.
- **Last updated:** 2026-10-13.

## Owner decisions (2026-10-12/13)
- Flutter app for web, Android and iOS.
- Minors may use the app (minimum age and legal review still open: Q2b).
- Monthly budget $0 with no billing account; Firebase-only stack: Authentication + Cloud Firestore + FCM.
- Native Android/iOS should attempt background location while the screen is locked, subject to OS permissions and restrictions; web only while tab is open.
- Travel history opt-in; 30-day default retention.
- Place detection runs on-device; event validation/deduplication needs a trusted processing path.

## What changed in v0.3
Owner selected Firebase-only: Authentication + Cloud Firestore + FCM; the prior database/backend option has been removed. Native Android/iOS background tracking should continue with the screen locked when permissions and OS policies allow; web remains foreground-tab only. Minor-safety requirements FR-102–104 remain. Free quotas limit scale.

## Review update (2026-10-13)
- Updated architecture, data model, security/privacy, roadmap, requirements, and review findings for Firebase-only.
- **P0 blocker:** Firebase Cloud Functions require Blaze, so trusted remote FCM sending, privileged operations, and scheduled cleanup have no approved server under strict Spark/no-billing. Do not embed server credentials in the app.
- Additional pre-build checks: circle-scoped Firestore Rules, safe join-code/membership flows, real-device background-location tests, and map/geocoder policy compliance.
- No application code was implemented and no build/test run was possible because the repository currently contains planning documents only.

## Increment 1 (2026-10-13) — status
**Written:** Flutter app (auth, age gate, profile, create/join/leave circles, member list, owner remove, rotate code), Firestore rules + indexes, rules tests, unit/widget tests, CI workflow (docs/ci/ci.yml), AGENTS.md, .env.example, test plan.
**Verified:** Nothing executed yet. Flutter SDK and the Firestore emulator download were unavailable in the authoring sandbox, so `flutter analyze/test`, the app build, and `npm test` are **Not run/Blocked**; the CI workflow (docs/ci/ci.yml; must be copied to .github/workflows/ to run) will run them. Expect to fix compile/lint/rule issues on first CI run.
**Deferred from Increment 1:** approval flow (FR-014), ownership transfer/circle deletion (FR-018), account deletion (FR-006), member cap (FR-021), email verification (FR-007), profile photos, location permission screen (FR-005).
**Needs owner:** create a free Firebase (Spark) project, enable Email/Password + Firestore, provide config via `--dart-define`; run `flutter create` (README) for platform folders.

## Increment 2 (2026-10-13) — status
**Written:** circle-scoped live location (rules + 9 new rule tests), Map tab with member list/details, Location sharing screen (consent dialog, per-circle opt-in, pause-all, permission states), sharing engine (geolocator; throttle + heartbeat), log-out stops sharing, platform setup doc + script, Dart unit tests for status/throttle.
**Verified:** nothing executed (same sandbox limits as Increment 1). Background reliability, battery, and the platform script are **Not run**; real-device matrix is in docs/platform-setup.md.
**Not built (by scope):** directions link (FR-072), timed pause (FR-038), in-app "you were added/sharing started" notices (FR-094 remote deferred), email verification, profile photos.

## Planning artifacts
PROJECT_BRIEF.md, requirements.md, architecture.md, design/{design-system,screen-specification,design-prompts}.md, docs/{user-flows,data-model,security-privacy,traceability,risks,roadmap,review-findings}.md, docs/decisions/ADR-0001..0004.

## Not created (and why)
- **design/screens/ images:** no mockup images have been generated yet; prompts are in design/design-prompts.md.
- **docs/api-spec.md, deployment.md, operations.md:** deferred until architecture and server-side push decision are approved.
- **AGENTS.md, docs/test-plan.md, release docs, CI, .env.example:** created after approval (Phases 6–7).

## Unverified items (must verify from official docs before building)
Current Firestore quotas and Rules behavior, trusted no-cost server option for remote push/privileged operations, map tile/geocoder terms, store fees/policies, package versions, and real-device background tracking.

## Outstanding questions
requirements.md §13 (Q1b, Q2b, Q3, Q7, Q8, Q9, Q11, Q12), plus the security, trusted-server, background tracking and map-provider spikes listed in docs/review-findings.md.

## Next steps
1. Push Increment 1 and read the first CI results; fix failures.
2. Owner decision on the P0 blocker (trusted no-cost server for push/cleanup, or reduced scope).
3. Run the rules tests in the Emulator and review results.
3. Verify current provider quotas and map/geocoder terms.
4. Owner approves baseline → date recorded here.
5. Phase 6: repo setup, then the security, background-location, and provider spikes.
