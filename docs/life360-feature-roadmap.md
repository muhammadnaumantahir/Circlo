# Circlo feature roadmap — Life360-inspired, $0-first

Last reviewed: 2026-10-29 (reconciled with merged PRs #60–#67 and current `main`; see [canonical feature status and cross-chat handover](feature-status.md)). Current branch `feature/sos-emergency-message` prototypes manual SOS-message handoff and Call/prefilled-SMS actions for explicitly shared Circle phone numbers; static review caught and corrected malformed duplicated contact-helper source; the message builder now also rejects invalid/non-finite coordinates and invalid accuracy. It is not merged and tests/build have not run. Code being in `main` does not mean tests or device behavior are verified. The latest Cloudflare Pages check for main SHA `73bfa1134113d94e4472da44d69a241c517e10e4` failed on 2026-10-29; the GitHub summary has no root-cause details, so inspect the linked provider logs before attempting a fix.

**Current next step:** release verification is P0 before adding more safety-sensitive behavior. First inspect the [failed Cloudflare Pages check](https://github.com/muhammadnaumantahir/Circlo/runs/123427066200) for main SHA `73bfa1134113d94e4472da44d69a241c517e10e4`; determine the root cause from provider logs and rebuild after fixing it. Then run the manual-only Flutter analyzer/tests and Firestore Emulator Rules suite and test Android/iOS background behavior and two-account privacy flows. No automated workflow should be triggered automatically.

This is an implementation queue, not a claim that Life360 features are equivalent. Circlo remains a consent-based location-sharing app. Every feature must respect the current Firebase-only, no-billing decision and be marked as verified only after the relevant tests run.

## Release gates (must stay visible throughout feature work)

- [ ] Inspect/fix the failed Cloudflare Pages check for main SHA `73bfa1134113d94e4472da44d69a241c517e10e4`, then confirm a successful production build.
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
| 8 | SOS message handoff / emergency contacts | In progress in [draft PR #68](https://github.com/muhammadnaumantahir/Circlo/pull/68) (not merged; tests not run) | Draft prepares a user-reviewed message for manual share/copy; stale fixes are omitted and Bubble pins are labelled approximate. Call and prefilled SMS are available only for Circle members who explicitly shared their number with that Circle; self, former/non-members and malformed phone values are filtered out. Text remains an unsent draft until the user confirms. No auto-send, delivery/read acknowledgement, remote push, address-book access or emergency dispatch. The screen re-evaluates freshness every minute without extra Firebase reads; boundary tests plus paused/unconfirmed sharing-state widget tests and invalid-coordinate/accuracy tests are authored but not run. Trusted delivery remains future work after safety review. |
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

## Delivery rule

Implement one feature at a time in its own branch/PR. Update this table and the feature audit with the actual code scope and test status. Do not run CI automatically; the workflow stays `workflow_dispatch` only. Merge only after reviewing the diff and documenting checks that have actually run.
