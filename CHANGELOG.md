# Changelog

## [Unreleased]
### Fixed
- Travel-history privacy: Firestore now checks the master “Keep my travel history” switch before allowing circle-copy reads or writes, blocking subsequent server-side reads when the switch is off. Data already cached on recipients’ devices cannot be remotely recalled.
- Location sharing recovery: the permission card refreshes when Circlo resumes after system Settings and offers retry if permission status cannot be checked. The screen also retries loading circles after a connection error.

### Added
- Circle invitations: show a QR code, share invites through the system share sheet, and open web invite links with the join code prefilled. Web invite destinations are preserved through login, email verification and new-user profile setup. Invite/QR actions are disabled while expiry is loading, cannot be checked, or the code is expired.
- Increment 1 (foundation): Flutter app skeleton (web/Android/iOS), email/password sign-up/log-in/log-out/password-reset with age gate (13+), profile setup and edit, create circle, join with code, member list, leave circle, owner removes members, owner rotates join code.
- Firestore Security Rules (default deny, circle-scoped) with emulator tests; GitHub Actions CI workflow (stored in docs/ci/ci.yml until enabled).
- Increment 2 (location sharing): Map tab (OpenStreetMap-based, flutter_map) with circle switcher and member list, per-circle opt-in sharing with consent dialog, pause-all, permission handling, status (Sharing / Paused / Location unavailable / Not sharing) with last-updated, throttled uploads + heartbeat, atomic stop/cleanup on pause, leave, removal and log-out; circle-scoped location rules + tests; platform setup script/doc.
- Increment 3 (places): saved places per circle (search on submit via a free geocoder, tap-to-pin, radius 100–1000 m, edit/delete), per-user alert preferences (arrive/leave, all or selected members), on-device arrival/departure detection with hysteresis and per-visit de-duplication, in-app Notifications feed and in-app announcements, places drawn on the map; rules + tests.
- Increment 4 (travel history): opt-in "Keep my travel history", daily compact history (visits ≥10 min + thinned route) recorded while sharing is on, History tab (member/date pickers, route + timeline with stay durations), per-circle history sharing with consent, retention 7/30/90 days (client-side cleanup), delete range/all, copies removed when switching off/leaving/logging out; rules + tests.
- Increment 5 (circle lifecycle): email verification gate (also enforced by rules), optional join-code expiry (24 h / 7 d), approval-required circles with request → approve → join, ownership transfer, circle deletion, best-effort account deletion with re-authentication and owner checks; rules + tests.
- Increment 6 (notifications and polish): activity events (member joined/left/removed, sharing started/stopped), one in-app feed with place alerts, "location unavailable" (15+ min, once per outage) and join requests, notification settings per kind and per circle, unread badge/read state, directions link, timed pause (1 h / until 6:00 / manual, auto-resume while the app is open), export my data (JSON); rules + tests.
### Authentication and premium UI (2026-10-28)
- Added Firebase-backed Google Sign-In for web (Firebase popup) and Android/iOS (Google ID token exchanged for a Firebase credential), using the same google_sign_in 7.x flow as FinMate and Stockly.
- Kept Circlo's age gate: Google-authenticated users without a profile must still provide a valid birth year; the profile name is prefilled from Google when available.
- Added Google reauthentication before destructive account deletion for Google-authenticated users.
- Documented Firebase provider/domain/OAuth setup and extended the platform helper to configure generated Android/iOS OAuth settings when local refreshed Firebase config files are present.
- Switched the global palette to a premium blue/mint/violet scheme and added gradient brand cards, a branded Google button, reusable colored icon chips, and icon polish for circles, places, notifications, history, and navigation.

### UI and reliability polish (2026-10-28)
- Premium forest-green/warm-neutral light and dark themes, polished shared cards/forms/empty states, responsive desktop navigation, and refreshed login/profile presentation.
- Map/People full-screen toggle on compact screens, visible web-tab tracking limitation, stale-sync warning with retry, and circle role cards that avoid extra per-circle listeners.
- Improved places and notification feed cards with capacity/alert states.
- Fixed place-alert restoration to reset completed visits correctly and prevent stale duplicate departure events; added a regression test.
- Hardened sharing shutdown so a failed position stream cannot keep the heartbeat publishing stale coordinates.
- Heartbeats now request a fresh medium-accuracy position; initial, streamed and heartbeat fixes with stale timestamps are not republished as fresh.
- Serialized notification preference saves to prevent rapid switch changes from overwriting one another; failed saves roll back locally.
- History recording retries a failed initial restore from Firestore instead of proceeding without the prior daily track.
- Hardened Firestore live-location privacy: list queries filter `sharing == true`, direct reads require the marker and current per-circle consent, pause/stop/removal require atomic location deletion, and orphaned child data is unreadable when a parent circle is missing.
- Added Firestore Emulator regression tests for pause/stop-without-delete, legacy locations, orphaned circle data and safe parent-circle deletion; added a manual CI job for the emulator rules suite.
- Place-alert listeners use generation guards and discard queued alerts when a circle stops sharing; circle deletion removes locations first and deletes memberships in small batches to respect Firestore rule limits.
- Fixed a heartbeat generation race after share-scope changes, prevent late native-stream errors from stopping a newer session, and ignore late location-upload results from an older sharing session.
- Pending place events now retry the member-name lookup on later location fixes if the initial lookup failed while offline.

### Deferred / unverified release blockers
- Remote phone push notifications are deferred under the current $0/no-billing decision; the feed is in-app only.
- Background tracking on Android/iOS, platform setup script, security rules, and all Flutter tests remain unverified in this authoring environment.
- Profile/circle pictures and a server-enforced member cap are not implemented under the current constraints.
- Scheduled retention, complete recursive account deletion, and trusted server-side place-event validation remain best-effort/deferred.
