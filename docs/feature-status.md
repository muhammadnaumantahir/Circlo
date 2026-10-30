# Circlo Feature Status & Cross-Chat Handover

**Last updated:** 2026-10-30  
**Latest status audit:** 2026-10-30 — reconciled against merged PRs #60–#71. PR #71 merged the join-code Rules compatibility, separate permission-denied diagnosis, responsive Circle entry screens and regression tests. Rules deployment, Flutter/Firestore tests and Cloudflare Pages verification remain pending.
**Repository:** [muhammadnaumantahir/Circlo](https://github.com/muhammadnaumantahir/Circlo)  
**Tracked branch:** `main`  
**Latest feature merges at audit:** PR #68 (manual SOS message/contact handoff), PR #69 (Place Suggestions syntax repair), PR #70 (Cloudflare Dart compile repairs) and PR #71 (join-code/web UI fixes), merged 2026-10-30
**Latest feature merge commit:** `74082021b9b73ce8fb69dea64173a74ba9daf2fd` — merge PR #71.  
**Tracker initially added:** `2ac3124e8a24c5c9b06820f117384b8af2456dae`

This is the canonical progress handover for Circlo. Update this file whenever a feature is started, implemented, merged, deferred, or verified. Also update [the detailed Life360-inspired roadmap](life360-feature-roadmap.md), [the feature audit](feature-audit-2026-10-28.md), and [the test plan](test-plan.md) whenever the change affects them. A feature in `main` means code is present, **not** that its tests passed or that it is production-ready.

## Latest join-code and web UI update (merged via PR #71)

- **PR:** [#71 — Fix join-code compatibility and polish Circle web entry](https://github.com/muhammadnaumantahir/Circlo/pull/71), merged 2026-10-30.
- **Merge commit:** `74082021b9b73ce8fb69dea64173a74ba9daf2fd`.
- **Join-code compatibility:** Firestore Rules accept an absent or explicit-null `expiresAt` as no expiry. Non-null expiry values must be future Firestore timestamps; expired and malformed values remain rejected. Missing/null legacy `requiresApproval` defaults to open, matching the app; unexpected values fail closed. The live Firebase document was not inspected, so explicit-null expiry is a confirmed source-level mismatch but not confirmed as the only cause of the reported account failure.
- **Error diagnosis:** a permission-denied join is reported separately from an invalid/expired code, with a hint to verify the account email and deployed Rules. The verified-email requirement is unchanged.
- **Web UX:** first-use onboarding, Create Circle and Join Circle use branded responsive two-panel layouts on wide screens and stacked layouts on narrow screens. Join codes are uppercased and grouped while typing.
- **Verification:** Firestore Rules and widget regression tests were added but not run. The updated Rules still need deployment to the intended Firebase project, followed by a real two-account test. Flutter analyzer/tests and Cloudflare Pages build remain unverified.

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
