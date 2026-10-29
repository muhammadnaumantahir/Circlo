# Circlo feature roadmap — Life360-inspired, $0-first

Last reviewed: 2026-10-29 (No Show alert edge-case coverage added; tests not run)

This is an implementation queue, not a claim that Life360 features are equivalent. Circlo remains a consent-based location-sharing app. Every feature must respect the current Firebase-only, no-billing decision and be marked as verified only after the relevant tests run.

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
| 1 | **Quick Notes with emoji** | Ported to current main branch; tests not run | One tap shares a curated emoji/message to the selected circle's in-app activity feed. Circle members only; fixed approved choices; no GPS fields; not a push notification. |
| 2 | Member call/text shortcuts | Implemented in code; tests not run | Per-circle phone opt-in, Call/Text actions on circle member cards and map details, owner-only private profiles, atomic phone updates and cleanup on opt-out/membership changes. |
| 3 | Better ETA and map handoff | Implemented in code; tests not run | Member details offer driving, walking, cycling and transit modes and hand route/ETA calculation to Google Maps; Circlo does not display an in-app estimate. |
| 4 | Low-battery status/alerts | Implemented in code; tests not run | Per-circle opt-in; uses battery_plus to attach valid 0–100% readings to normal location updates, displays last-reported status and warns at 20% or below in-app. Off by default; no push or guaranteed background delivery. |
| 5 | Scheduled No Show alerts | Implemented in main; edge-case hardening merged; tests added but not run | One expected-arrival plan per member and circle, with in-app overdue/late-arrival feed entries while Circlo is open; future-dated location timestamps are treated as potentially unavailable; no remote push or guaranteed background scheduler. |
| 6 | Automatic Place Suggestions | Implemented in code; tests not run | Optional private-history analysis, off by default; requires both Keep Travel History and separate opt-in; only local candidate computation, at least 3 visits across 3 days; dismissed per view; explicit review before saving to the selected circle. No background scanning or push alert. |
| 7 | Remote push notifications | Deferred | Requires a trusted sending path. Keep deferred under the current no-billing setup; never ship sender credentials in client code. |
| 8 | SOS and emergency contacts | Safety review required | Separate opt-in contacts and a tested alert path; clearly show delivery state and fallback. No false assurance of emergency response. |
| 9 | Driving reports and crash detection | Native research required | Platform-specific background motion/crash detection, false-positive handling, permissions and real-device validation before user-facing claims. |
| 10 | Temporary approximate-location Bubble | Planned, privacy review required | Let a user intentionally share a coarse location for a limited time; never silently change precise-sharing consent. |
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

## Delivery rule

Implement one feature at a time in its own branch/PR. Update this table and the feature audit with the actual code scope and test status. Do not run CI automatically; the workflow stays `workflow_dispatch` only. Merge only after reviewing the diff and documenting checks that have actually run.
