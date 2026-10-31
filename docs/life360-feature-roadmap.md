# Circlo feature roadmap — Life360-inspired, $0-first

Last reviewed: 2026-10-31 (reconciled with merged PRs #60–#75; see [canonical feature status and cross-chat handover](feature-status.md)). PR #75 repairs the previous web compile errors. A reported Circle-list failure after successful creation is under investigation; Rules/index deployment, tests and live Firebase behavior remain unverified.

**Current next step:** distinguish the Circle-list query's Firebase error code, confirm the production Firebase project has the repository's current firestore.rules and firestore.indexes.json, then retest Circle creation/listing. Run `cd app && flutter analyze && flutter test` and `cd firebase && npm test` manually; deploy Rules/indexes only to the verified target project with owner approval. GitHub Actions remains manual-only.

This is an implementation queue, not a claim that Life360 features are equivalent. Circlo remains a consent-based location-sharing app. Every feature must respect the current Firebase-only, no-billing decision and be marked as verified only after the relevant tests run.

## Circle list recovery and Firestore diagnostics (reported 2026-10-31)

- The app finds Circle membership through the own-UID members collection-group query. Repository Rules already define own-document-only collection-group access and the indexes file already defines the members.uid collection-group index.
- The live Firebase project's deployed Rules and index status are not visible from repository source and still need verification.
- The diagnostic branch maps permission-denied to a Rules/project mismatch hint, failed-precondition to the members.uid index hint, and network/auth failures to their own messages. Successful creation also invalidates the Circle stream and selects the newly-created Circle.
- The patch does not relax Firestore Rules, add collections, or introduce paid services. Unit tests have been authored but not run.

## Latest join-code and web UX update (merged via PR #71)

- PR #71 is merged into `main`. Firestore Rules accept absent/null `expiresAt` as no expiry; expired and malformed values remain blocked. Code creation and join validation use the same expiry semantics.
- Missing/null legacy `requiresApproval` defaults to open, matching the app; unexpected values fail closed.
- Permission-denied join failures are no longer presented as invalid/expired codes. The message points to account email verification and deployed Rules; verified-email authorization is unchanged.
- First-use onboarding and Create/Join screens use responsive gradient-hero/form panels on wide web layouts and stacked mobile layouts. Invite codes are uppercased and grouped while typing.
- Regression coverage was added for expiry/approval edge cases, the full membership/contact-cleanup/activity join batch, invite formatting and wide-screen layout. Tests have not been run.

## Premium UI refresh (merged via PR #72)

- App-wide light/dark theme now uses semantic blue/mint/violet tokens, consistent typography, rounded cards and clearer controls.
- Shared components provide gradient hero cards, page headings, glass-style surfaces, profile identity panels, metric tiles and category icon chips, plus branded loading/recovery.
- Desktop navigation has a branded sidebar, privacy cue and account footer; mobile bottom navigation remains.
- Circles, Places, Travel History, Activity and Profile have stronger information hierarchy. The map remains full-bleed.
- This is presentation-only. Sharing consent, data, routes and circle-gating behavior are unchanged. Tests and responsive visual verification have not run.

## Premium UI refinement (merged via PR #73)

[PR #73](https://github.com/muhammadnaumantahir/Circlo/pull/73) follows PR #72 with deeper polish across the Map, Circles, Places, Profile and sign-in surfaces. It adds semantic status capsules, grouped settings rows, glass-card page controls, better mobile-fit status labels and refined theme states for switches and segmented controls. Presentation-only; no location, membership or Firebase behavior is changed. Widget tests have been expanded but are not run.

## Follow-up premium UI refinement (merged via PR #74)

Merged via [PR #74 — Polish Circlo History and Activity with premium UI](https://github.com/muhammadnaumantahir/Circlo/pull/74)

- The follow-up pass extends the shared style to History and Activity: compact selectors, quick date filters, clearer daily summaries and stop cards, plus grouped privacy/history and notification preference surfaces.
- A shared `PremiumFilterChip` provides consistent selected states, counts, iconography and a 44px minimum touch target.
- Visual-only: Circle membership, location-sharing consent, history retention/deletion, notification preference writes, Firebase schema/rules and navigation destinations are unchanged.
- A filter-chip widget regression test has been added. Flutter tests/analyzer and mobile/tablet/desktop light/dark browser review are still required. GitHub Actions remains manual-only.

## Cloudflare web compile repair (merged via PR #75)

[PR #75 — Fix Cloudflare Flutter web compilation errors](https://github.com/muhammadnaumantahir/Circlo/pull/75) merged on 2026-10-31 (merge commit `62732922787fec587328c13a15311358b47c524b`).

- The 2026-10-30 Pages log identified a missing `PremiumSectionHeader` shared widget and one extra closing parenthesis in the Map people preview.
- The repair branch restores the compact const header component, fixes the Map widget closure and adds a widget regression test.
- Source corrections are in `main`. Flutter analyze/tests and a new web release build still need to be run. Dependency-update notices and the Wasm dry-run notice are not compile blockers.

## Release gates (must stay visible throughout feature work)

- [ ] Run the manual GitHub Actions workflow for Flutter analyze/tests and Firestore Emulator rules tests when ready.
- [ ] Test authorization with multiple accounts and circles; don't treat in-app activity as trusted evidence.
- [ ] Verify Android/iOS tracking with the screen locked, app backgrounded, battery saver and offline recovery.
- [ ] Validate map/geocoder provider limits, attribution and availability before public release.
- [ ] Keep the GitHub Actions workflow manual-only. Never put Firebase service-account credentials or FCM server credentials in the Flutter app.
- [ ] Do not describe Circlo as an emergency-dispatch or crash-detection service until native behavior and a trusted alert path are proven.

## Feature queue

| Order | Feature | Status | Scope and acceptance criteria |
|---:|---|---|---|
| 1 | **Quick Notes with emoji** | In main via [PR #62](https://github.com/muhammadnaumantahir/Circlo/pull/62); tests not run | One tap shares a curated emoji/message to the selected circle's in-app activity feed. Circle members only; fixed approved choices; no GPS fields; not a push notification. |
| 2 | Member call/text shortcuts | In main via [PR #64](https://github.com/muhammadnaumantahir/Circlo/pull/64); tests not run | Per-circle phone opt-in, Call/Text actions on circle member cards and map details, owner-only private profiles, atomic phone updates and cleanup on opt-out/membership changes. |
| 3 | Better ETA and map handoff | In main via [PR #61](https://github.com/muhammadnaumantahir/Circlo/pull/61); tests not run | Member details offer driving, walking, cycling and transit modes and hand route/ETA calculation to Google Maps; Circlo does not display an in-app estimate. |
| 4 | Low-battery status/alerts | In main via [PR #65](https://github.com/muhammadnaumantahir/Circlo/pull/65); tests not run | Per-circle opt-in; uses battery_plus to attach valid 0–100% readings to normal location updates, displays last-reported status and warns at 20% or below in-app. Off by default; no push or guaranteed background delivery. |
| 5 | Scheduled No Show alerts | In main via [PR #60](https://github.com/muhammadnaumantahir/Circlo/pull/60) and hardening [PR #66](https://github.com/muhammadnaumantahir/Circlo/pull/66); tests not run | One expected-arrival plan per member and circle, with in-app overdue/late-arrival feed entries while Circlo is open; future-dated location timestamps are treated as potentially unavailable; no remote push or guaranteed background scheduler. |
| 6 | Automatic Place Suggestions | In main via [PR #63](https://github.com/muhammadnaumantahir/Circlo/pull/63); tests not run | Optional private-history analysis, off by default; requires both Keep Travel History and separate opt-in; only local candidate computation, at least 3 visits across 3 days; dismissed per view; explicit review before saving to the selected circle. No background scanning or push alert. |
| 7 | Remote push notifications | Deferred | Requires a trusted sending path. Keep deferred under the current no-billing setup; never ship sender credentials in client code. |
| 8 | Manual SOS message/contact handoff | In main via [PR #68](https://github.com/muhammadnaumantahir/Circlo/pull/68); partial / unverified | User reviews and shares/copies a prepared SOS message; Call and unsent prefilled SMS are available only for current Circle members who explicitly shared a valid number. Map links require active sharing and a fresh fix; Bubble pins are labelled approximate; contact actions fail closed until UID is confirmed. No auto-send, delivery/read acknowledgement, remote push or emergency dispatch. Run tests and real-device handler/privacy checks. |
| 9 | Driving reports and crash detection | Native research required | Platform-specific background motion/crash detection, false-positive handling, permissions and real-device validation before user-facing claims. |
| 10 | Temporary approximate-location Bubble | In main via [PR #67](https://github.com/muhammadnaumantahir/Circlo/pull/67); tests not run | Per-circle opt-in with 1/4/8-hour expiry; the live map pin is snapped to a 0.02° grid (roughly 1–1.6 km), exact location document is deleted on transition, Firestore Rules require coarse coordinates during the unexpired window, and directions are disabled for coarse pins. Expiry is client-driven: precise sharing resumes while the app is active or on the next sync after reopen; no server scheduler/push. Other features such as place alerts, manual check-ins and separately enabled Travel History may still disclose visits. |
| 11 | Flight detection and landing alerts | Lower priority / integration needed | Only through a suitable source with clear limitations and no implied real-time guarantee. |
| 12 | Item trackers and pet tracking | Lower priority / integration needed | Requires external device/provider integration; keep separate from core member location sharing. |

## Implemented in Circlo already

- Circle create/join, invites, QR/share links, membership approvals and lifecycle controls.
- Consent-based per-circle live location sharing, pause/resume, map and member status.
- Saved Places with per-user arrival/departure preferences and device-side in-app activity.
- Opt-in Travel History, route/timeline and deletion controls.
- In-app activity feed, member manual check-ins, curated quick emoji notes, filters and unread state.
- Optional on-device place suggestions from the user's own retained private history, behind a separate opt-in and a review-before-save step; not saved or shared until confirmed.
- Circle-first onboarding that hides map-dependent navigation until a user belongs to a circle.
- One expected-arrival plan per member/circle with in-app No Show and late-arrival entries; no server-scheduled or phone-push guarantee.
- Optional per-circle Approximate Location/Bubble: a temporary grid-snapped map location, with previous location projection deleted during transition and explicit disclosure of independent alert/history features.
- Manual SOS message/contact handoff (PR #68): user-reviewed share/copy plus opt-in Circle Call and prefilled Text handoff, with no automatic delivery or emergency-dispatch claim.

## Delivery rule

Implement one feature at a time in its own branch/PR. Update this table and the feature audit with the actual code scope and test status. Do not run CI automatically; the workflow stays `workflow_dispatch` only. Merge only after reviewing the diff and documenting checks that have actually run.
