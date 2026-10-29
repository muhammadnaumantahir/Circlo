# Changelog

## [Unreleased]
### Added
- Added optional per-circle battery sharing, included only in existing location-sync writes after explicit consent. The map and People list show last-reported battery status, a low-battery warning at 20% or below, and timestamp context; opting out clears the shared location projection immediately. No push or guaranteed background alert is claimed.

### Fixed
- Gate map, saved places, travel history and related routes until the signed-in user belongs to a circle; route initial/no-membership states and membership-query errors with no cached result to one Circles screen instead of showing repeated Retry states across tabs.
- Use the first-use Circles onboarding to guide users through creating a circle or joining by invite code, hide circle-dependent tabs before membership, open the map after a successful join, and offer an Open map action on circle details after membership is confirmed.
- Fix Circles screen web compilation: use the available icon palette for circle-card tones and preserve a promoted non-null user ID in the join-code rotation callback.
- Preserve completed Travel History days for retry when a Firestore write fails during midnight rollover, instead of silently dropping the prior day while moving to the new day.
- Serialize Travel History fix processing, drain pending callbacks before final flush, and persist stationary last-seen times on the configured flush cadence.
- Make Travel History deletion load all saved day keys across Firestore pages, so deleting all history cannot leave older records behind after the 200-day display limit.
- Ignore duplicate-timestamp GPS callbacks in place-arrival detection so repeated copies of one fix cannot satisfy the multi-fix confirmation threshold.
- Share the first Travel History restore between concurrent GPS callbacks so an overlapping Firestore read cannot replace newer in-memory tracking state with a stale snapshot.
- Bound restored Travel History timestamps to the supported date range and reset invalid timezone offsets, preventing malformed metadata from crashing date/time rendering.
- Reject invalid GPS fixes and out-of-order timestamps in Travel History recording so malformed samples cannot pollute a route or roll the active day backward.
- Ignore malformed travel-history route points and visits when restoring a day, so one corrupt nested record cannot crash the whole history timeline.
- Reject malformed saved-place subscription boolean flags instead of silently disabling alerts or treating a malformed pause flag as resumed; legacy documents that omit these fields keep their defaults.
- Reject malformed saved-place subscription `allMembers` values rather than accidentally interpreting them as enabled; legacy documents without the field still default to all members.
- Reject shared-location documents with malformed accuracy values instead of treating them as zero-accuracy GPS fixes; legacy documents with no accuracy field remain compatible.
- Prevent malformed Firestore display-name values from causing runtime cast errors in location-sharing and place-event flows; ignore malformed one-off place-subscription reads instead of throwing.
- Make circle, member and join-request model parsing tolerate malformed Firestore string and timestamp fields without runtime cast failures.
- Safely reject saved-place documents with non-string names and tolerate malformed optional creator values without crashing place streams.
- Ignore malformed optional timed-pause timestamps when reading membership documents, keeping the sharing-state stream alive.
- Skip malformed place-event documents so bad legacy records cannot break the in-app feed or place-state restoration.
- Ignore malformed saved place-subscription documents so one bad document cannot break the user's subscription stream.
- Scope place-alert detector state by circle and place ID so same-named document IDs in different circles cannot interfere with arrival/departure events.
- Reject invalid GPS coordinates or accuracy before writing shared locations to Firestore, instead of silently normalizing negative accuracy.
- Ignore out-of-order GPS samples in saved-place arrival/departure detection so delayed callbacks cannot advance confirmation or create false transitions.
- Skip malformed saved-place documents in the live places stream so bad coordinates or radii cannot break place tracking.
- Ignore malformed GPS samples and invalid saved-place coordinates/radii in arrival/departure detection to prevent false safety alerts.
- Fix the account-deletion circle reference and guard relative-time labels against future timestamps.
- Skip malformed or out-of-range shared-location documents so one invalid Firestore record cannot break the live-location stream; add regression tests.
- Treat shared-location timestamps more than two minutes in the future as unavailable instead of falsely showing a member as actively sharing; add regression coverage for large and small clock skew.
- Clarified the timed location-sharing pause choice as “Until 6:00 AM”; it can resume at 6:00 AM today when selected before 6:00 AM, or the next day when selected later.

### Changed
- Extended the family map to surface each member's latest manual check-in in member details and the People list, including timestamp and optional saved-place context. It is explicitly labeled self-reported and not GPS-verified; existing activity data is reused.
- Added manual circle check-ins (I'm okay, Arrived safely, On my way, Running late) from the map header. Users can optionally attach a saved-place name/ID, which is validated against the circle's saved place; check-ins remain self-reported and never include GPS coordinates. A dedicated notification category can be muted.
- Grouped filtered activity into Upcoming, Today, Yesterday, Last 7 days and Earlier sections with per-section counts, preserving category filters, search and unread labels.
- Polished the Travel History timeline with richer stop cards, arrival/departure chips, stay duration and an explicit open/last-seen state for unfinished records, plus a one-tap map control to fit the selected route and stops.
- Improved Travel History with one-tap Today / Yesterday / 7 days ago shortcuts and a compact daily summary of recorded stops, simplified route points, and last recorded fix; privacy and retention behavior are unchanged.
- Added map-wide People search and Sharing, Paused, Unavailable and Not sharing filters; the selected filters apply to both the People list and visible map markers, and reset when switching circles.
- Added search across activity text, circle names and event categories, plus category chips for All, Places, People and Location with counts and a clear-filter empty state. This uses the existing in-app feed only and does not add push delivery or backend cost.
- Upgraded Saved Places with a per-circle alert dashboard, alert-state filters, one-tap pause/resume and live search. Pause is now stored separately from arrival/departure choices, so resuming retains the exact event types and selected-member preferences; legacy subscription documents default to unpaused.
- Refreshed the visual identity with an indigo-to-teal palette, a branded Circlo map header, family-map member name markers, tap-to-open member detail sheets, and a mobile people-preview dock with quick access to saved places and sharing settings.
- Reworked the Circles screen with a private-by-design overview card and clearer member cards, while keeping existing circle actions and Firebase-only behavior.
### Fixed
- Protect existing place alert preferences when their document cannot be loaded: alert controls and saving stay disabled until the read succeeds, with an explicit retry instead of silently overwriting settings with defaults.
- Map and People status labels now refresh every minute while the screen is open, so locations transition to unavailable after the freshness threshold even if no new snapshot arrives. This is a local UI refresh and does not increase Firestore reads or writes.
- Travel-history privacy: Firestore now checks the master “Keep my travel history” switch before allowing circle-copy reads or writes, blocking subsequent server-side reads when the switch is off. Data already cached on recipients’ devices cannot be remotely recalled.
- Location sharing recovery: the permission card refreshes when Circlo resumes after system Settings and offers retry if permission status cannot be checked. The screen also retries loading circles after a connection error.
- Account deletion now chunks bulk document cleanup into batches of 400, keeps location and membership revocation atomic, and retains history day keys until reachable circle copies are handled to support safer retries.

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
