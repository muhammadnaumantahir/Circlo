# Changelog

## [Unreleased]
### Fixed
- Extend PR #72's premium UI alignment across the Map, Circles, Places, Profile and sign-in flows (merged via [PR #73](https://github.com/muhammadnaumantahir/Circlo/pull/73)): elevated dashboard surfaces, semantic sharing/role pills, grouped privacy settings, saved-place capacity, inline auth errors and refined interactive theme states. Expanded widget coverage; tests and responsive browser/device review remain pending.
- Align Circlo's app-wide palette, typography, cards, controls and light/dark surfaces with the shared FinMate / Stockly premium design language (merged via [PR #72](https://github.com/muhammadnaumantahir/Circlo/pull/72)). Add reusable page headers, glass cards, metric tiles and profile heroes; refresh desktop account navigation and main feature-page hierarchy. Visual-only; tests and web/device review remain pending.
- Treat an explicit Firestore `expiresAt: null` the same as a missing expiry for join codes, and default a missing or null legacy `requiresApproval` field to `false` in join Rules. Past and malformed expiry values remain rejected. Merged via [PR #71](https://github.com/muhammadnaumantahir/Circlo/pull/71); Rules must be deployed before the live two-account test.
- Report join permission-denied failures separately from genuinely invalid/expired codes, with an account-verification and Rules-deployment hint; the verified-email security check remains intact (PR #71).
- Refresh first-use onboarding and Create/Join Circle screens with branded, responsive desktop panels, stacked narrow layouts, inline error cards and uppercase, grouped join-code input. Widget and Firestore Rules regression tests added via [PR #71](https://github.com/muhammadnaumantahir/Circlo/pull/71); not run.
- Fix the approximate-location confirmation copy in `sharing_screen.dart` with a valid Dart triple-quoted string; the prior raw newline terminated a single-quoted string and stopped web compilation (merged via [PR #70](https://github.com/muhammadnaumantahir/Circlo/pull/70)).
- Restore `sos_contact.dart` as one complete recipient-filtering implementation with a properly terminated E.164-style phone-number RegExp; remove the orphaned duplicate tail and duplicate URI declarations that caused parser errors (merged via [PR #70](https://github.com/muhammadnaumantahir/Circlo/pull/70)).
- Add the missing `SharingController._disposed` lifecycle flag and set it during provider disposal so the delayed Bubble-expiry retry is not scheduled after disposal (merged via [PR #70](https://github.com/muhammadnaumantahir/Circlo/pull/70)).
- Extend SOS contact regression coverage for whitespace-only unresolved signed-in UIDs. PR #70 is merged; analyzer/tests and a successful Cloudflare Pages build are still pending.
- Fix the approximate-location confirmation copy in `sharing_screen.dart` by using a valid multiline Dart string; the prior raw newline terminated a single-quoted string and stopped web compilation.
- Restore `sos_contact.dart` as one complete recipient-filtering implementation with a properly terminated E.164-style phone regex; remove the orphaned duplicate tail that caused parser errors and duplicate URI declarations.
- Add the missing `SharingController._disposed` lifecycle flag and set it during provider disposal so the delayed Bubble-expiry retry is not scheduled after disposal.
- Extend SOS contact regression coverage for whitespace-only unresolved signed-in UIDs.
- Repair malformed Dart source in `app/lib/features/places/place_suggestions.dart` (merged via [PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69)): restore the `track.visits` loop inside `buildPlaceSuggestions` and remove the orphaned duplicate implementation fragment. Existing malformed-day-key regression coverage remains. Flutter analyzer/tests and the Cloudflare Pages build still need verification.
- Make the SOS message builder fail closed on invalid latitude/longitude, non-finite values and invalid accuracy even if a malformed `MemberLocation` reaches the helper. Regression cases were added; tests have not run.
- Correct the malformed duplicate in the SOS contact helper discovered during review of PR #68. Recipient filtering and dialer/SMS URI helpers are restored; regression coverage includes malformed phone-number forms, but no tests or build checks have run.
- Fail closed for SOS contact actions until the signed-in user ID is resolved. The recipient helper returns no contacts and the UI explains that Call/Text actions are hidden rather than risking showing the current user's contact; a regression test was added, but no tests or build checks have run.

### Added
- Add a Circle-gated, user-reviewed SOS message handoff (merged via [PR #68](https://github.com/muhammadnaumantahir/Circlo/pull/68)): share or copy a prepared message, with a last-shared map link only when Circle location sharing is active and the fix is fresh; approximate Bubble pins are labelled and stale/unavailable/invalid coordinates are omitted. The screen distinguishes sharing-off/paused/unconfirmed and location-loading/error states, and refreshes freshness locally each minute without extra Firebase reads.
- Add Call and prefilled Text actions only for current Circle members who explicitly shared a valid phone number with that Circle. Self, former/non-members and malformed numbers are excluded; actions fail closed until the signed-in UID is resolved. Call opens the dialer and Text opens an unsent draft for user review; no automatic send, delivery/read acknowledgement, remote push or emergency dispatch is provided.
- On map screens narrower than 440 px, move Check-in and SOS into the Quick actions menu to reduce app-bar overflow risk while keeping Notifications and Profile accessible.

### Added
- Add per-circle Approximate Location (Bubble): choose 1, 4 or 8 hours to share a grid-snapped map pin (~1–1.6 km) instead of exact coordinates. The old live location is deleted during precision changes, the map shows the coarse-pin uncertainty region and label, and directions are disabled for coarse pins. Expiry is client-side; if the app is closed, precise sharing resumes on the next sync after reopen. Place alerts, manual check-ins and separately opted-in Travel History remain independent and can still disclose visits.

### Added
- Add optional per-circle battery sharing, piggybacked on normal location sync. The map and People list show the last reported percentage and an in-app warning at 20% or below; opting out clears the shared location projection. No phone push or guaranteed background alert is claimed.
- Add per-circle phone-sharing consent and Call/Text shortcuts in circle member cards and map details. Private profiles remain owner-only; shared copies are synchronized and removed when consent or membership ends.
- Add optional Automatic Place Suggestions from the user's own private Travel History: local on-device clustering of unlabeled stops seen on at least three different days, with explicit opt-in, retention-window bounds, dismissible cards, and a review step before saving into a circle. No coordinates are uploaded by the suggestion engine itself.

### Added
- Add one reschedulable expected-arrival plan per member and circle, with saved-place deadlines and in-app No Show warnings for circle members when no arrival has been recorded by the deadline. Confirmed arrivals resolve plans; late arrivals remain visible in the notification feed. This is evaluated while Circlo is open and actively tracking; no phone push or guaranteed background scheduling is claimed.
- Add curated one-tap emoji Quick Notes to the map check-in sheet. Messages are restricted by Firestore Rules to approved emoji/text pairs, shared to the selected circle's in-app feed, and carry no GPS fields.

### Changed
- Add a route-mode chooser to member map details (driving, walking, cycling and public transport) and hand off the selected mode to Google Maps for route/ETA calculation. Circlo does not display an in-app estimate or require a paid directions API.

### Fixed
- Hardened No Show alert evaluation: future-dated location timestamps more than two minutes ahead are described as potentially unavailable, and extracted overdue/arrival matching into a testable helper with regression coverage.
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
