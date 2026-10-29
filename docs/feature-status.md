# Circlo Feature Status & Cross-Chat Handover

**Last updated:** 2026-10-29  
**Latest status audit:** 2026-10-29 — reconciled against merged PRs #60–#67. Expected-arrival/No Show hardening (#66), battery sharing (#65), phone sharing (#64), place suggestions (#63), Quick Notes (#62), route handoff (#61), scheduled No Show (#60), and Approximate Location/Bubble (#67) are already in `main`. Cloudflare Pages succeeded at `167192e` (Quick Notes) and first failed at `1a0942b` (Automatic Place Suggestions); later main commits also failed. Static review found malformed Dart source in `app/lib/features/places/place_suggestions.dart` introduced in that regression window. A focused draft repair is on [PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69); provider logs remain inaccessible, so the source-based diagnosis still needs confirmation from a successful build.
**Repository:** [muhammadnaumantahir/Circlo](https://github.com/muhammadnaumantahir/Circlo)  
**Tracked branch:** `main`  
**Latest application/code commit at audit:** `9e460f613a5a5f0dbc5438d80dd16b85ddc11f91` — PR #67, Approximate Location (Bubble)  
**Tracker initially added:** `2ac3124e8a24c5c9b06820f117384b8af2456dae`

This is the canonical progress handover for Circlo. Update this file whenever a feature is started, implemented, merged, deferred, or verified. Also update [the detailed Life360-inspired roadmap](life360-feature-roadmap.md), [the feature audit](feature-audit-2026-10-28.md), and [the test plan](test-plan.md) whenever the change affects them. A feature in `main` means code is present, **not** that its tests passed or that it is production-ready.

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
| 9 | Automatic Place Suggestions | In main — web build blocker under repair | On-device suggestions derived from the user's own retained private Travel History; default-off separate opt-in, bounded history reads, dismissible cards, and review-before-save. [PR #63](https://github.com/muhammadnaumantahir/Circlo/pull/63). The current source has a malformed loop/duplicate fragment; proposed syntax fix is [draft PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69). | Merge only after Flutter analyze/tests and Cloudflare Pages build succeed; also test retention, opt-out, no-history, deduplication, and review flow. |
| 10 | Per-Circle phone sharing / Call / Text | In main — unverified | Phone number is shared only by explicit per-Circle consent; Call/Text opens the device handler; private profile stays owner-only. [PR #64](https://github.com/muhammadnaumantahir/Circlo/pull/64) | Run Rules/model tests; test opt-out, phone change, member removal, account deletion and Android/iOS/web handlers. |
| 11 | Low-battery status | In main — partial | Optional per-Circle battery consent, battery percentage piggybacked on normal location sync, last-reported label and in-app warning at 20% or below. [PR #65](https://github.com/muhammadnaumantahir/Circlo/pull/65) | Test consent isolation and stale values. It is **not** a phone push notification or guaranteed background warning. |
| 12 | Temporary approximate location / Bubble | In main — partial | Per-Circle 1/4/8-hour coarse map pin, grid snapping/uncertainty label, deletion of old live projection during precision changes, Directions disabled for coarse pins. [PR #67](https://github.com/muhammadnaumantahir/Circlo/pull/67) | Test expiry, app-closed behavior and other independent disclosure paths. Expiry is client-driven; place alerts, check-ins and opted-in History can still reveal visits. |
| 13 | Web build error fix | In main — previous code fix, new regression open | Earlier `backgrounds`, integer-index, and nullable `uid` fixes remain in [PR #53](https://github.com/muhammadnaumantahir/Circlo/pull/53). Current regression: malformed source in Place Suggestions; focused repair is in [draft PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69). | Run analyzer/tests and confirm a successful Cloudflare Pages build after the repair merges; provider log diagnosis is still unavailable. |
| 14 | In-app activity / manual check-ins | In main — unverified | Searchable activity feed, filters, unread state, membership/location/place events, self-reported check-ins and Quick Notes. | Cross-account authorization, feed parsing, stale/offline states and UI tests. These are in-app items, not remote phone pushes. |

## Recommended next steps (keep this section current)

1. **Release verification first (P0):** review [draft PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69), which repairs the definite malformed Dart source found in Place Suggestions; then run the manual-only Flutter analyzer/tests and Firestore Emulator Rules suite, and confirm Cloudflare Pages succeeds. Provider logs were not accessible, so a successful build is still required to validate the source-based diagnosis. Verify Android/iOS background tracking and two-account privacy behavior before release.
2. **Next product feature after verification:** design an SOS / emergency-contact flow only after defining consent, delivery acknowledgement, retry/fallback, abuse controls, and truthful “sent/delivered” states. Do not describe it as emergency dispatch without a tested trusted delivery path.
3. **Keep deferred under $0/Firebase-only:** remote push notifications until a trusted no-cost delivery architecture is confirmed; never embed sender credentials in the client.
4. Then evaluate driving/crash detection, flight/landing alerts, tracker integrations and pet tracking as listed below.

## Not implemented or deferred

| Priority | Feature | Status | Next step / limitation |
|---:|---|---|---|
| P0 | Release verification | Required before release | Review [draft PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69) for the malformed Place Suggestions source fix; run manual Flutter analyze/tests and Firestore Emulator Rules tests; confirm Cloudflare web build; test Android/iOS background tracking and two-account privacy flows. |
| P1 | Remote push notifications | Deferred | Requires a trusted delivery path. Do not put server credentials in the Flutter app. Reassess only after confirming a truly no-cost deployable architecture. |
| P2 | SOS / emergency contacts | Not started — safety critical | Design consent, delivery acknowledgement, fallback, abuse controls and real-device tests before claiming emergency support. |
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
| #59 Automatic Place Suggestions | Closed, not merged | Superseded by the privacy-reviewed implementation in PR #63. |

## Release checklist

- [ ] Flutter analyzer and full app tests pass on the manual CI workflow.
- [ ] Firebase Emulator Rules tests pass.
- [ ] Merge/verify the Place Suggestions source fix in [PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69), then confirm latest `main` builds successfully on Cloudflare Pages.
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
