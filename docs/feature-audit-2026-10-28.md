# Circlo Feature Audit — 2026-10-28

This audit reflects a static review of the current Flutter source and project requirements. **“Implemented in code” does not mean tested, production-ready, or reliable in the background.** Flutter/Dart and the Firebase Emulator were not available in the authoring environment, and no real-device runs were performed.

## What exists in the code

| Area | Current implementation | Confidence / limit |
|---|---|---|
| Accounts | Email/password sign-up, login, password reset, email verification gate, birth-year age gate, profile edit | Source exists; end-to-end flow not run |
| Circles | Create/join by code, code rotation/expiry, pending join approval, member removal/leave, ownership transfer, circle deletion | Source and rules tests exist; emulator test suite not run |
| Location sharing | Per-circle opt-in with consent, pause/resume (manual, 1 hour, or until 6:00), permission help, live-location documents and status derivation | Background behavior not verified on devices |
| Map | Circle switcher, member markers/status, last-update details, saved-place overlays and external directions | Public tile provider must be chosen/validated before release |
| Places | Search submitted manually through a free geocoder, tap-to-pin fallback, 100–1000 m radius, per-user arrive/leave preferences and selected members | Detection is device-side; requires the sharing app to receive location fixes |
| Notifications | In-app feed, unread badge/read timestamp, kind filters, muted circles, join/sharing/place activity | **In-app only**. No phone push to closed apps |
| History | Opt-in daily history, circle-specific sharing, route thinning, visits/stay duration, date/member picker, 7/30/90-day client-side cleanup, deletion controls | Device-side recording and cleanup are best-effort, not server-guaranteed |
| Privacy controls | Per-circle location/history switches, pause, leave/remove, export view/copy, account deletion workflow | Account/circle cleanup is client-side best-effort; deleted data cannot always be fully enumerated |
| Platform support | Flutter project designed for web, Android and iOS | Native Android/iOS folders are generated locally and are not committed; background permissions/service setup remains unverified |

## Improvements made on the current UI branch

- Added a consistent light/dark theme, reusable empty-state presentation, polished circle/place cards, and responsive desktop navigation.
- Circle cards use a role label without starting a separate live member listener for every circle, avoiding extra reads.
- The sharing screen shows tracking state, the last successful location sync, flags syncs older than 10 minutes, and offers retry.
- A location-stream failure now cancels the heartbeat before cleanup so the app does not keep republishing a stale position.
- The map clearly tells web users that sharing stops when the tab is closed, and compact screens can switch between a full map and a full-height People list.
- The profile screen and in-app notification feed use clearer identity, privacy and activity cards.
- Notification preference saves are serialized; controls are disabled during writes and local choices roll back if a save fails.
- History restoration retries after a transient Firestore read failure instead of permanently proceeding without the existing daily track.
- Fixed place-alert restoration so the latest departure resets stale “inside” state; added a regression test for the next visit.
- Places display used capacity and whether their arrival/departure alerts are enabled.

## Important gaps before release

1. **Run the automated checks.** Run `cd app && flutter pub get && flutter analyze && flutter test`, then run `cd firebase && npm ci && npm test` with the Firestore Emulator available. These checks have not been executed for this branch.
2. **Prove Firestore authorization.** Test with at least two accounts and two circles that users cannot read another circle's locations/history, impersonate members, self-approve, or keep access after leaving/removal. Do not store sensitive real-world location data until rules tests pass.
3. **Test native location behavior.** Generate the platform folders, apply `tools/apply_platform_config.py`, then test Android/iOS with screen locked, app backgrounded/closed, battery saver, revoked permissions and offline recovery. Current code does not prove Life360-style reliability.
4. **Keep remote push deferred.** Under the current Firebase Spark / $0 no-billing decision there is no approved trusted sender for cross-user FCM. Do not add FCM server credentials to the Flutter app. Arrival/departure/activity feed is not delivered when recipients' apps are closed.
5. **Choose a production map/geocoder provider.** Current map configuration is configurable, but the development/default public tile service is not a production guarantee. Follow the provider's caching, rate-limit, attribution and usage policies.
6. **Treat deletion and retention as best-effort.** Client-side cleanup cannot enumerate all orphaned circle copies or guarantee scheduled deletion when users do not open the app.
7. **Resolve product/legal blockers.** Review minors' age policy, privacy policy, store disclosures and background-location justifications. Profile/circle photos and server-enforced member caps are not implemented under the current no-billing setup.

## Practical status

The main feature flows are represented in source code, but **Circlo is not yet release-verified**. The highest priority is correctness/security verification and real-device location testing, not adding more dependencies or claiming remote/background behavior that has not been proven.
