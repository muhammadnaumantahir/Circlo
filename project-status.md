# Project Status

- **Current phase:** Hardening and release preparation.
- **Baseline:** v0.3, Firebase-only, $0/no-billing scope.
- **Current implementation status (2026-10-30):** Main includes Firebase Google Sign-In, a family-map dashboard, searchable People and status filters, QR/share-sheet circle invitations, web invite links, manual check-ins, Saved Places and per-user alert controls, a searchable activity feed, Travel History and settings, account/circle/location sharing flows, and privacy/reliability hardening. First-time users now land on a focused Create-or-Join Circle onboarding screen; Map, Places and History navigation appears only after membership exists, successful joins open the selected circle's map, and circle-detail screens offer an Open map action.
- **Latest Cloudflare compile repair (2026-10-31):** merged via [PR #75](https://github.com/muhammadnaumantahir/Circlo/pull/75) (`62732922787fec587328c13a15311358b47c524b`), restoring the missing shared `PremiumSectionHeader` component and removing a surplus Map-panel parenthesis reported in the 2026-10-30 Pages log. Widget coverage added; analyzer, tests, and release web build still pending.
- **Circle list loading incident (2026-10-31):** a Circle write succeeds, but the Circles screen reports that the membership list cannot load. Source uses the own-UID members collection-group query; repository Rules and the members.uid collection-group index are present in Git, but deployment to the production Firebase project is unverified. Diagnostic messaging and refresh-after-create are merged via [PR #76](https://github.com/muhammadnaumantahir/Circlo/pull/76) (`83074b42be21968c37ca2647f3565537f6669da5`) on fix/circles-load-error-diagnostics-oct31; no Rules/index deployment or CI run has occurred.
- **Verification status:** Not release-verified. The owner will run CI/build checks manually; Flutter analyze/tests and Firebase Emulator Rules tests have not been run here. PR #71's Firestore Rules still need deployment and a real second-account join test. PR #72–#73 premium UI widget tests, Flutter analyzer, responsive web review and Pages build still need manual verification. Google OAuth still needs Firebase Console setup; QR/share-sheet behavior and Android/iOS background location need real-device tests.
- **Latest hardening:** Live-location reads require the active-sharing marker and current per-circle consent for direct gets; pause/stop/removal require atomic deletion. Heartbeats reject stale fixes, async sharing/place-listener operations are generation-guarded, and queued place events retry their member-name lookup after offline recovery. Travel History retains completed days for retry after midnight rollover write failures. Fixed the reported Circles screen web compilation errors. Circle-dependent routes now funnel users without memberships, or whose initial circle query fails before any cached membership data is available, to the Circles screen rather than repeating the same Retry state on every feature tab. Map status and relative-time labels refresh locally each minute while the map is open.
- **Still deferred by the owner's current scope:** remote cross-user push, scheduled cleanup, guaranteed complete account/circle deletion, trusted server-side validation of place events. Manual check-ins are user-reported messages, not verified location or emergency monitoring.
- **Latest merge (2026-10-30):** [PR #71](https://github.com/muhammadnaumantahir/Circlo/pull/71) merged join-code null-expiry/legacy-approval compatibility, clearer permission-denied diagnosis and responsive Circle onboarding/Create/Join screens. Rules/widget regression tests are in `main` but not run; updated Rules still need deployment and a real two-account verification.
- **Latest UI refresh (2026-10-30):** PR #72 merged the FinMate / Stockly-aligned Circlo theme, shared premium components, desktop account navigation and refreshed Circles, Places, History, Activity and Profile headers. Visual-only; no location/privacy behavior changed.
- **Latest premium UI refinement (2026-10-30):** PR #73 merged premium Map controls, Circle cards, Places capacity, grouped Profile settings and a contained login panel. Visual-only; widget tests, Flutter analyzer and responsive browser/device review remain pending.
- **Last reviewed:** 2026-10-31. See [the current feature audit](docs/feature-audit-2026-10-28.md) for the feature inventory, recent improvements, and release blockers.

> Historical note: the increment-by-increment sections below are dated snapshots from 2026-10-13/14. Their “not built” and “next steps” statements describe the state at that time and are not the current feature inventory. The feature audit above is the current summary.

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

## Increment 3 (2026-10-13) — status
**Written:** places (Places tab, add/edit/delete with search + tap-to-pin + radius), per-user alert preferences, on-device detector + engine wired into the sharing controller, event publishing, in-app Notifications screen and snackbar announcements, places overlay on the map, rules + 9 new rule tests, detector/geocoder unit tests.
**Verified:** nothing executed (same sandbox limits). Real two-device movement test and background reliability remain **Not run**.
**Limits by owner decision:** alerts are in-app only; no remote push; no automatic cleanup of events.
**Not built:** per-notification-type settings (FR-081 beyond per-place), read/unread state (FR-082), "you were added/sharing started" notices, directions link, history.

## Increment 4 (2026-10-13) — status
**Written:** history models + pure `TrackBuilder` (visits, route thinning, day rollover, restore), `HistoryRecorder` wired into the sharing controller, repository, History tab (member/date pickers, route + timeline), History settings (keep, retention, per-circle sharing, delete range/all), copy cleanup on sharing-off/leave/log-out, retention cleanup, rules + 6 new rule tests, track-builder tests.
**Verified:** nothing executed (same sandbox limits). Real-device recording, battery, and quota are **Not run**.
**Limits by owner decision:** retention/deletion are client-side best-effort; no server cleanup.
**Not built:** reverse geocoding of unknown places, trip/driving detection, data export (FR-093), notification type settings (FR-081), read state (FR-082).

## Increment 5 (2026-10-14) — status
**Written:** email verification (screen + rules), join-code expiry, approval flow (toggle, requests list, approve/reject, auto-complete join), ownership transfer, circle deletion, best-effort account deletion (re-auth, owner blockers, data steps, Auth user last), pending-request cards; rules + 10 new rule tests; model tests.
**Verified:** nothing executed (same sandbox limits).
**Still not built:** member cap (FR-021, rules cannot count), profile/circle pictures (Cloud Storage needs billing; initials only), push (deferred by owner), notification-type settings/read state/membership notices (next increment), directions link, timed pause, data export.

See [docs/requirements-status.md](docs/requirements-status.md) for a requirement-by-requirement table.

## Increment 6 (2026-10-14) — status
**Written:** activity events + unified in-app feed (place, membership, sharing, unavailable, join requests), notification settings (kinds + muted circles), unread badge, directions link, timed pause with auto-resume, data export; rules + 7 new rule tests; tests for directions/export.
**Verified:** nothing executed (same sandbox limits).
**Requirements status:** all Must/Should/Could items that are possible at $0 without a server are now written in code. **Not built, by constraint:** FR-021 member cap (rules cannot count), profile/circle pictures (Cloud Storage needs billing; initials shown), remote push / FR-084 (needs a paid server), guaranteed retention/deletion (client-side best effort), reverse geocoding of unknown places, driving/trip detection and other "later version" items.
**Everything is unverified:** no code has been compiled or run; first CI run, rules tests on the emulator and a real-device test are the gate before any release.

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
