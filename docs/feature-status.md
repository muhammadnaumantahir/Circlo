# Circlo Feature Status & Cross-Chat Handover

**Last updated:** 2026-10-31  
**Latest status audit:** 2026-10-31 — `main` reconciled through merged PRs #60–#76. PR #75 repaired the previous Cloudflare compile errors. PR #76 adds Circle-list Firebase error diagnostics and refresh-after-create. The 2026-10-31 live error confirms the `members.uid` COLLECTION_GROUP/ASCENDING index is missing in Firebase project `circlo-1dbda`; the exact definition is already present in `firebase/firestore.indexes.json` but has not yet been created/verified in that project. Flutter tests/analyzer and live Firebase verification remain pending.
**Repository:** [muhammadnaumantahir/Circlo](https://github.com/muhammadnaumantahir/Circlo)  
**Tracked branch:** `main`  
**Latest feature merges at audit:** PR #68 (SOS handoff), PR #69 (Place Suggestions repair), PR #70 (Cloudflare compile repairs), PR #71 (join-code compatibility), PR #72 (initial premium UI), PR #73 (premium UI refinement) and PR #74 (History / Activity premium polish), PR #75 (Cloudflare web compile repair) and PR #76 (Circle-list error diagnosis), merged 2026-10-30/31
**Latest feature merge commit:** `83074b42be21968c37ca2647f3565537f6669da5` — squash merge PR #76.  
**Tracker initially added:** `2ac3124e8a24c5c9b06820f117384b8af2456dae`

This is the canonical progress handover for Circlo. Update this file whenever a feature is started, implemented, merged, deferred, or verified. Also update [the detailed Life360-inspired roadmap](life360-feature-roadmap.md), [the feature audit](feature-audit-2026-10-28.md), and [the test plan](test-plan.md) whenever the change affects them. A feature in `main` means code is present, **not** that its tests passed or that it is production-ready.

## Latest join-code and web UI update (merged via PR #71)

- **PR:** [#71 — Fix join-code compatibility and polish Circle web entry](https://github.com/muhammadnaumantahir/Circlo/pull/71), merged 2026-10-30.
- **Merge commit:** `74082021b9b73ce8fb69dea64173a74ba9daf2fd`.
- **Join-code compatibility:** Firestore Rules accept an absent or explicit-null `expiresAt` as no expiry. Non-null expiry values must be future Firestore timestamps; expired and malformed values remain rejected. Missing/null legacy `requiresApproval` defaults to open, matching the app; unexpected values fail closed. The live Firebase document was not inspected, so explicit-null expiry is a confirmed source-level mismatch but not confirmed as the only cause of the reported account failure.
- **Error diagnosis:** a permission-denied join is reported separately from an invalid/expired code, with a hint to verify the account email and deployed Rules. The verified-email requirement is unchanged.
- **Web UX:** first-use onboarding, Create Circle and Join Circle use branded responsive two-panel layouts on wide screens and stacked layouts on narrow screens. Join codes are uppercased and grouped while typing.
- **Verification:** Firestore Rules and widget regression tests were added but not run. The updated Rules still need deployment to the intended Firebase project, followed by a real two-account test. Flutter analyzer/tests and Cloudflare Pages build remain unverified.

## Latest UI refresh (merged via PR #72)

- **PR:** [#72 — Refresh Circlo with FinMate / Stockly premium UI](https://github.com/muhammadnaumantahir/Circlo/pull/72), merged 2026-10-30.
- **Merge commit:** `828b71c593732dcf1798d732e7746b2abc85b6a0`.
- **Design system:** semantic blue/mint/violet palette, refreshed light/dark themes, rounded cards/controls, stronger typography, gradient hero treatment and branded loading/recovery.
- **Desktop:** wider workspace sidebar, privacy panel and signed-in account card. Mobile bottom navigation remains unchanged.
- **Screens:** Circles, Saved Places, Travel History, Activity and Profile have improved page hierarchy. Map remains full-bleed and map-first.
- **Behavior:** presentation-only; circle gating, membership, location sharing, privacy defaults and Firebase data flows are unchanged.
- **Verification:** widget tests were added but not run. Flutter analyzer/tests, web build, responsive browser review and Android/iOS verification remain outstanding. GitHub Actions remains manual-only.

## Latest premium UI refinement (merged via PR #73)

- **PR:** [#73 — Polish Circlo with a more premium app-wide UI](https://github.com/muhammadnaumantahir/Circlo/pull/73), merged 2026-10-30.
- **Merge commit:** `875bc13c5035a11c295422bb1d41e0e063849e6d`.
- **Shared design system:** added semantic status pills, grouped glass-card sections and category-coloured setting tiles. Refined switch, checkbox, radio and segmented-control states for light/dark themes.
- **Map:** premium active-circle selector and sharing state, single People search/filter surface and elevated floating people panel. Map remains full-bleed.
- **Circles / Places:** ownership/member labels on circle cards, premium circle selector and saved-place capacity indicator.
- **Profile / Authentication:** grouped profile form and privacy actions, separate destructive-action surface, contained login panel and inline errors.
- **Behavior:** presentation-only; Firebase schema, membership, sharing consent, routes and location data behavior are unchanged.
- **Verification:** widget tests were expanded but not run. Flutter analyzer/tests, responsive browser review, Cloudflare Pages build and Android/iOS checks remain outstanding. GitHub Actions stays manual-only.

## Follow-up premium UI refinement (merged via PR #74)

- **PR:** [#74 — Polish Circlo History and Activity with premium UI](https://github.com/muhammadnaumantahir/Circlo/pull/74), merged 2026-10-30.
- **Merge commit:** `1ef9aaac1696b08460bcbc7b27e54acf76046727`.
- **Shared component:** `PremiumFilterChip` adds selected/unselected styling, optional icon/count, semantic label/state and a 44px minimum touch target.
- **History:** refreshed Circle/member and date selectors, quick-date filters, daily summary, stop timeline and grouped personal-history, per-Circle sharing and deletion settings.
- **Activity:** refreshed category filters and feed cards; notification preferences are grouped by activity type and Circle. The app-bar back action remains available.
- **Behavior / privacy:** presentation-only. Existing consent checks, Circle membership, data queries, retention/deletion, notification preference writes, routes, Firebase schema and Rules are unchanged.
- **Verification:** a filter-chip widget test was added. Flutter tests/analyzer, browser review at mobile/tablet/desktop widths, dark-mode review and Cloudflare Pages build have not been run. GitHub Actions remains manual-only.

## Cloudflare web compile repair (merged via PR #75)

- **PR:** [#75 — Fix Cloudflare Flutter web compilation errors](https://github.com/muhammadnaumantahir/Circlo/pull/75), merged 2026-10-31.
- **Merge commit:** `62732922787fec587328c13a15311358b47c524b`.
- **Branch:** `fix/cloudflare-web-compile-errors-oct31`.
- **Build log:** 2026-10-30 Cloudflare Pages `flutter build web --release` failed in Dart compilation. The package-update and Wasm dry-run lines are warnings/information, not the root cause.
- **Root cause 1:** `PremiumSectionHeader` was used in sign-up and Circle forms without a declaration in shared widgets. PR #75 restored it as a reusable const widget, resolving the sign-up missing-method error and the Circle const-expression errors.
- **Root cause 2:** `_PeoplePeekCard` in `map_screen.dart` had an extra closing parenthesis after its `Column`; PR #75 removed that unmatched closure.
- **Regression test:** a widget test now covers the shared header title/subtitle.
- **Verification:** source changes are merged into `main`; Flutter analyzer, widget tests, `flutter build web --release` and a Cloudflare Pages deploy have not been run. Do not claim build success until the new release build passes.

## Circle created but Circle list fails to load (confirmed missing live index)

- **Reported:** 2026-10-31 — the user successfully created a Circle, but the Circles screen still displays “Could not load your circles”.
- **Current source path:** myCirclesProvider → CirclesRepository.watchMyCircles(uid) → Firestore collectionGroup('members').where('uid', isEqualTo: uid). A failure from this membership query puts CirclesScreen into its error state.
- **Repository checks:** firebase/firestore.rules contains the own-UID collection-group access rule; firebase/firestore.indexes.json already defines the members.uid ascending collection-group index; firebase/tests/rules.test.mjs tests the same query.
- **Confirmed live cause from the 2026-10-31 screenshot:** Firestore returned failed-precondition and explicitly requested a COLLECTION_GROUP_ASC index for collection `members`, field `uid`, in Firebase project `circlo-1dbda`. The index definition is already tracked in Git; the live project is missing the index or it is not yet ready.
- **PR:** [#76 — Diagnose Circle list failures after successful creation](https://github.com/muhammadnaumantahir/Circlo/pull/76), merged 2026-10-31.
- **Merge commit:** `83074b42be21968c37ca2647f3565537f6669da5`.
- **Code change on fix/circles-load-error-diagnostics-oct31:** replace generic retry copy with an error-code-specific explanation; preserve Firestore's message (including index-link details) for diagnosis; invalidate myCirclesProvider and set the new Circle as selected after the creation batch succeeds.
- **Next action:** open the exact Create Index URL shown by Firestore, create the `members` / `uid` / Collection group / Ascending index in `circlo-1dbda`, wait until its status is Enabled, then reload Circlo and retry. Do not create a duplicate or loosen Rules.
- **Verification:** a focused Dart unit test covers permission-denied, failed-precondition, connectivity and unexpected errors. Flutter tests/analyzer and Firestore Emulator Rules tests have not been run. The live index has not yet been confirmed Enabled and the browser retest remains pending. No GitHub Actions workflow was triggered.

## Status definitions

- **In main — unverified:** implementation is merged, but its required automated/device checks have not been confirmed as passing.
- **Partial / platform-limited:** useful behavior exists, but it relies on an external app, an active client, or has known limitations.
- **Not started:** no implementation confirmed in `main`.
- **Deferred:** intentionally not implemented under the current $0 / Firebase-only constraints.

## Implemented in `main`

| # | Feature / area | Status | Scope already present | Verification still needed |
|---:|---|---|---|---|
| 1 | Circle-first onboarding | In main — unverified | Create/Join screen for members without a Circle; Map, Places and History navigation unlocks after membership; recovery is centralized in Circles. [PR #54](https://github.com/muhammadnaumantahir/Circlo/pull/54) | Test new account, create, join, pending approval, no-network and returning member flows. |
| 2 | Circle management and invitations | In main — unverified | Create/join, invite code, QR/share links, approval requests, member removal/leave, ownership transfer and Circle deletion. | Two-account Firestore Rules and end-to-end invite tests. |
| 3 | Live location and map | In main — unverified | Per-Circle sharing consent, map/People list, status freshness, pause/resume, location permission recovery, approximate-location Bubble. | Android/iOS locked-screen and background behavior; battery saver, offline recovery, stale data, web map UX. |
| 4 | Saved Places / arrival & departure | In main — unverified | Saved places, per-member/per-place alert preferences, arrival/departure detection and in-app activity. | Radius accuracy, duplicate/out-of-order fixes, real-device background tracking, Rules/emulator tests. |
| 5 | Expected arrival / No Show alerts | In main — partial | One expected-arrival plan per member/Circle with deadline, schedule/change/cancel controls, in-app No Show/late-arrival entries; stale/future location timestamps are handled defensively. [PR #60](https://github.com/muhammadnaumantahir/Circlo/pull/60), [PR #66](https://github.com/muhammadnaumantahir/Circlo/pull/66) | These are **not** guaranteed when the app is closed; no remote push/server scheduler. Test time zones, stale/offline updates, reschedule/cancel and arrival resolution. |
| 6 | Travel History | In main — unverified | Opt-in daily route/visit history, summaries, date/member selection and deletion, with timestamp validation, serialized recording and retry on rollover write failures. [PRs #45–52](https://github.com/muhammadnaumantahir/Circlo/commits/main) | Run recorder/model tests; test midnight rollover, connectivity loss, retention and delete-all with real data. |
| 7 | Route / ETA handoff | In main — partial | Choose driving, walking, cycling or transit and pass the destination to Google Maps; live ETA is calculated externally, not in Circlo. [PR #61](https://github.com/muhammadnaumantahir/Circlo/pull/61) | Test app/browser handoff, missing Maps handler, all modes, web/mobile and approximate pins where directions must be disabled. |
| 8 | Quick Notes and emoji messages | In main — unverified | Eight curated one-tap messages in the map check-in sheet and Circle activity feed; no GPS fields. [PR #62](https://github.com/muhammadnaumantahir/Circlo/pull/62) | Run activity/model/Rules tests; verify current-member authorization and cross-Circle isolation. |
| 9 | Automatic Place Suggestions | In main — source repair merged; verification pending | On-device suggestions derived from the user's own retained private Travel History; default-off separate opt-in, bounded history reads, dismissible cards, and review-before-save. Original implementation [PR #63](https://github.com/muhammadnaumantahir/Circlo/pull/63); malformed loop/duplicate-fragment repair [PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69). | Run Flutter analyze and Place Suggestions tests; confirm a successful Cloudflare Pages build; test retention, opt-out, no-history, deduplication and review flow. |
| 10 | Per-Circle phone sharing / Call / Text | In main — unverified | Phone number is shared only by explicit per-Circle consent; Call/Text opens the device handler; private profile stays owner-only. [PR #64](https://github.com/muhammadnaumantahir/Circlo/pull/64) | Run Rules/model tests; test opt-out, phone change, member removal, account deletion and Android/iOS/web handlers. |
| 11 | Low-battery status | In main — partial | Optional per-Circle battery consent, battery percentage piggybacked on normal location sync, last-reported label and in-app warning at 20% or below. [PR #65](https://github.com/muhammadnaumantahir/Circlo/pull/65) | Test consent isolation and stale values. It is **not** a phone push notification or guaranteed background warning. |
| 12 | Temporary approximate location / Bubble | In main — partial | Per-Circle 1/4/8-hour coarse map pin, grid snapping/uncertainty label, deletion of old live projection during precision changes, Directions disabled for coarse pins. [PR #67](https://github.com/muhammadnaumantahir/Circlo/pull/67) | Test expiry, app-closed behavior and other independent disclosure paths. Expiry is client-driven; place alerts, check-ins and opted-in History can still reveal visits. |
| 13 | Web build error fix | In main — source repairs merged; deployment pending | Place Suggestions source repair is merged via [PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69). The next Cloudflare log identified broken multiline text, malformed/duplicated SOS helper source and an undefined SharingController disposal flag; all three source repairs are merged via [PR #70](https://github.com/muhammadnaumantahir/Circlo/pull/70). | Run Flutter analyze/tests and confirm a successful Cloudflare Pages deployment from latest `main`. |
| 14 | In-app activity / manual check-ins | In main — unverified | Searchable activity feed, filters, unread state, membership/location/place events, self-reported check-ins and Quick Notes. | Cross-account authorization, feed parsing, stale/offline states and UI tests. These are in-app items, not remote phone pushes. |
| 15 | SOS message and opted-in Circle contacts | In main — partial / unverified | Circle-gated, user-reviewed SOS message with share/copy; Call and unsent prefilled Text actions only for current Circle members who explicitly shared a valid phone number. Fresh active location links only; Bubble pins labelled approximate; contact actions fail closed until UID is confirmed. [PR #68](https://github.com/muhammadnaumantahir/Circlo/pull/68) | Run SOS helper/widget tests; verify share sheet, copy, phone handlers, narrow layouts and two-account privacy. No auto-send, delivery/read acknowledgement, remote push or emergency dispatch. |
| 16 | Join-code compatibility and responsive Circle entry | In main via [PR #71](https://github.com/muhammadnaumantahir/Circlo/pull/71) — verification pending | Missing/null join-code expiry is treated as no expiry; legacy missing/null approval settings default to open; permission-denied errors are distinguished from invalid codes; onboarding/Create/Join screens are redesigned for responsive web layouts. | Deploy Firestore Rules; test joining with a second verified account; run Rules and widget tests plus a web build. |

## Recommended next steps (keep this section current)

1. **Join-code fix first (P0):** PR #71 is merged. Deploy the updated Rules to the intended Firebase project, then retry the same invite using a second account with a verified email. Confirm the code's `expiresAt` is absent/null and check the Circle's approval setting (an approval-required Circle should create a pending request rather than a direct membership). If Firestore still denies the join, use the new permission-denied message to check the deployed Rules and account verification. Run the manual-only Flutter analyzer/widget tests and Firestore Emulator Rules suite, then confirm a successful Cloudflare Pages build. Do not mark this verified until Rules deployment and the two-account flow succeed.
2. **Validate the new SOS handoff (PR #68):** run its three regression test files and manually verify share/copy, Call/Text handlers, UID fail-closed behavior, approximate/stale location messaging, small-screen layout and two-account isolation. Keep the feature described as manual handoff only, not emergency dispatch.
3. **Keep deferred under $0/Firebase-only:** remote push notifications and trusted automatic emergency delivery until a secure, no-cost delivery architecture with acknowledgement/fallback is proven; never embed sender credentials in the client.
4. Then evaluate driving/crash detection, flight/landing alerts, tracker integrations and pet tracking as listed below.

## Not implemented or deferred

| Priority | Feature | Status | Next step / limitation |
|---:|---|---|---|
| P0 | Release verification | Required before release | PR #70's Dart compile repairs and PR #71's join-code/web UI fixes are merged. Still deploy the PR #71 Firestore Rules, run manual Flutter analyze/tests and Firestore Emulator Rules tests, confirm a successful Pages build from latest `main`, and test Android/iOS background tracking plus two-account privacy flows. |
| P1 | Remote push notifications | Deferred | Requires a trusted delivery path. Do not put server credentials in the Flutter app. Reassess only after confirming a truly no-cost deployable architecture. |
| P2 | Trusted SOS delivery / emergency dispatch | Deferred / not implemented | PR #68 provides manual message sharing/copy plus Call and unsent prefilled SMS for explicitly opted-in Circle contacts only. No automatic send, delivery acknowledgement, remote push, server scheduler or emergency-dispatch integration. A trusted delivery path, fallback, abuse controls and real-device tests remain prerequisites. |
| P3 | Driving reports / crash detection | Not started — native research | Native motion/location collection, false-positive controls, platform limits and real-device validation are needed. |
| P4 | Flight / landing alerts | Not started — external integration | Find a suitable data source; clearly disclose coverage and latency before implementing. |
| P4 | Tile/item tracker integration | Not started — external integration | Requires supported hardware/provider APIs and account linking. |
| P4 | Pet tracking | Not started — external integration | Requires a device/provider integration; not provided by phone-only GPS sharing. |
| P4 | Profile / Circle photos | Not started / constrained | Current UI uses initials; evaluate a no-billing image-storage option before adding uploads. |

## Open / superseded PR status at last audit

| PR | Status | Notes |
|---|---|---|
| #55 Quick Notes + roadmap | Closed, superseded | Closed 2026-10-29; Quick Notes is in `main` via PR #62. |
| #57 ETA map handoff | Closed, superseded | Closed 2026-10-29; ETA/map handoff is in `main` via PR #61. |
| #56 Call/Text | Closed, not merged | Superseded by the conflict-resolved implementation in PR #64. |
| #58 Battery sharing | Closed, not merged | Superseded by the conflict-resolved implementation in PR #65. |
| #59 Automatic Place Suggestions | Closed, superseded | Older proposal; the privacy-reviewed implementation is in `main` via PR #63 and its source repair via PR #69. |
| #68 SOS message/contact handoff | Merged 2026-10-30 | Code is in `main`; tests, web build and native behavior remain unverified. |
| #69 Place Suggestions source repair | Merged 2026-10-30 | Syntax correction is in `main`; analyzer/tests and a successful Cloudflare Pages deployment remain outstanding. |
| #70 Cloudflare follow-up compile repairs | Merged 2026-10-30 | Fixes multiline string, malformed SOS helper and missing SharingController disposal flag; analyzer/tests and Cloudflare deployment verification pending. |
| #71 Join-code compatibility and Circle web entry | Merged 2026-10-30 | Accepts absent/null expiry, aligns legacy approval defaults, distinguishes permission-denied failures and refreshes responsive Create/Join/onboarding screens; Rules deployment and tests pending. |
| #74 Premium History and Activity UI | Merged 2026-10-30 | Shared filter chip, refined History controls/timeline/settings and Activity feed/preferences; presentation-only. | Flutter tests/analyzer, responsive light/dark review and Cloudflare Pages build remain pending. |

| Cloudflare web compile repair | Merged 2026-10-31 via PR #75 | Restores the missing const PremiumSectionHeader and fixes the surplus Map-panel parenthesis from the Pages release compile log. | Flutter analyze/tests, fresh `flutter build web --release` and a successful Cloudflare Pages deployment remain pending. |

## Release checklist

- [ ] Flutter analyzer and full app tests pass on the manual CI workflow.
- [ ] Firebase Emulator Rules tests pass.
- [ ] Confirm a successful Cloudflare Pages deployment from latest `main` after PR #71 and deploy the updated Firestore Rules; run Flutter analyzer/tests and Firestore Rules tests through the manual workflow.
- [ ] Run Flutter analyzer/tests and Firestore Rules tests through the manual workflow.
- [ ] Run the SOS message/contact/widget tests from PR #68 and complete two-account + Android/iOS/web handler verification.
- [ ] Android and iOS tested with screen locked, app backgrounded, battery saver, denied permissions and offline recovery.
- [ ] Two-account tests confirm per-Circle isolation, opt-out deletion, member removal and account deletion.
- [ ] Firestore Rules deployed to the intended Firebase project and verified there.
- [ ] Feature claims and privacy policy match the real behavior (especially No Show, Bubble, battery status and phone notification limitations).

## Instructions for the next chat / future changes

1. Read this file first, then check the current `main` SHA and latest PRs. Do not assume the previous chat's branch or PR is still current.
2. Pick the next unfinished item only after confirming it is not already present in `main`.
3. Implement one feature per branch and PR; keep GitHub Actions manual-only.
4. Before reporting completion, review the diff and update this file, `docs/life360-feature-roadmap.md`, `CHANGELOG.md`, and `docs/test-plan.md` as applicable.
5. State clearly whether code is merely in `main`, tests were actually run, web deployment passed, and native behavior was verified.
