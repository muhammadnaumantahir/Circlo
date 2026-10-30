# Circlo Feature Audit — updated 2026-10-29

Use [feature-status.md](feature-status.md) as the canonical feature checklist and cross-chat handover. This audit reflects a static review of the current Flutter source and project requirements. **“Implemented in code” does not mean tested, production-ready, or reliable in the background.** Flutter/Dart and the Firebase Emulator were not available in the authoring environment, and no real-device runs were performed. Cloudflare Pages last succeeded on `167192e` and first failed on `1a0942b`; static review of `place_suggestions.dart` found an incomplete visit loop and orphaned duplicate code that constitutes a Dart source error. The repair is proposed in [draft PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69); provider logs were not accessible and build/tests remain unrun.

## What exists in the code

| Area | Current implementation | Confidence / limit |
|---|---|---|
| Accounts | Email/password and Google sign-up/sign-in, password reset, provider-aware verification, birth-year age gate, profile edit | Source exists; Firebase Console/OAuth and end-to-end Google flow not run |
| Circles | First-use Create/Join onboarding; map/places/history tabs gated until membership exists; create/join by code, QR and share-sheet invites, web invite links with prefilled code, code rotation/expiry, pending join approval, member removal/leave, ownership transfer, circle deletion, manual check-ins with optional saved-place context (place ID/name only, no GPS) | Source exists; emulator suite and end-to-end invite flow not run |
| Location sharing | Per-circle opt-in with consent, pause/resume (manual, 1 hour, or until 6:00), permission help, live-location documents, status derivation, and temporary per-circle Approximate Location/Bubble (grid-snapped pin for 1/4/8 hours) | Background behavior and Bubble expiry recovery not verified on devices; Bubble affects map precision only, not independent place alerts, manual check-ins or separately shared Travel History |
| Map | Circle switcher, status-aware name markers that open member details, mobile people-preview dock, active-sharing summary, quick access to saved places/sharing settings, saved-place overlays and external directions | UX needs manual phone/tablet/desktop and light/dark testing; public tile provider must be chosen/validated before release |
| Places | Free-geocoder search, tap-to-pin fallback, 100–1000 m radius, per-user arrival/departure preferences and selected members, searchable alert dashboard, persistent per-place pause/resume, opt-in private-history Place Suggestions with a review-before-save flow | Place Suggestions source in `main` currently has malformed Dart structure; proposed repair is [draft PR #69](https://github.com/muhammadnaumantahir/Circlo/pull/69). Tests/build remain unverified. |
| Notifications | Searchable, time-grouped in-app activity feed; category filters (All / Places / People / Location), per-section counts, unread badge/read timestamp, muted circles and join/sharing/place activity | **In-app only**. No phone push to closed apps |
| History | Opt-in daily history, circle-specific sharing, route thinning, visits/stay duration, date/member picker, quick date shortcuts, daily summary, rich stop timeline cards, map fit-route control, 7/30/90-day client-side cleanup and deletion controls | Device-side recording and cleanup are best-effort, not server-guaranteed |
| Privacy controls | Per-circle location/history switches, pause, leave/remove, export view/copy, account deletion workflow | Account/circle cleanup is client-side best-effort; deleted data cannot always be fully enumerated |
| Platform support | Flutter project designed for web, Android and iOS | Native Android/iOS folders are generated locally and are not committed; background permissions/service setup remains unverified |

## Improvements made on the current UI branch

- Added a Circle-first start flow inspired by Life360's create-or-join onboarding: new users see one focused setup screen, circle-dependent tabs stay hidden until membership exists, successful joins open the selected circle's map, and Circle details provide an Open map action. When the initial circle-list query fails before any membership data is available, feature routes return to a single Circles recovery screen rather than repeating Retry states across tabs. This is a source change; automated checks are not run yet.

- Added a consistent light/dark theme, reusable empty-state presentation, polished circle/place cards, and responsive desktop navigation.
- Added Firebase-backed Google Sign-In entry points on login and sign-up, with web popup and native ID-token flows. Google users retain the age-gate/profile-setup requirement, and destructive account deletion reauthenticates Google users.
- Added premium blue/mint/violet tokens, gradient brand cards, Google action styling and colorful icon chips for circles, places, notifications, history and navigation. Firebase OAuth provider/domain setup is documented, but Console configuration and live sign-in tests remain outstanding.
- Refreshed the visual identity to an indigo/teal gradient and made the map a family dashboard: member markers show readable names and open status/location detail sheets, while compact screens get a people preview and quick actions for saved places and sharing settings. The Circles screen now has a branded overview card and clearer member-role cards.
- The map member-details sheet and People list surface each member's latest available manual check-in with timestamp and optional saved-place name; check-ins are explicitly labeled self-reported and not GPS-verified, and no GPS coordinates are added to check-in data.
- Added cross-platform People search and live status filters (Sharing, Paused, Unavailable, Not sharing). Filtered members update both the People list and map markers; the selection resets when changing circles, and empty results offer a clear-filter action.
- Map and People relative-time labels and stale/fresh status are re-evaluated once per minute while the map screen is mounted; this is local-only and does not make additional Firestore requests.
- Circle invites can be shared with the system share sheet and shown as a QR code. On web, scanning/opening the QR link pre-fills the join code and preserves the requested route through sign-in/profile setup; native QR codes contain a readable Circlo join-code payload.
- Circle cards use a role label without starting a separate live member listener for every circle, avoiding extra reads.
- The sharing screen shows tracking state, the last successful location sync, flags syncs older than 10 minutes, and offers retry.
- The location-permission card rechecks when Circlo resumes after system Settings, so newly granted/revoked permission or re-enabled location services are reflected without manually restarting the app; a retry is available if the permission check itself errors.
- The Location sharing screen now offers a Retry action if its circles query fails, instead of leaving the user on a dead-end error state.
- A location-stream failure now cancels the heartbeat before cleanup. The five-minute heartbeat requests a fresh position, and initial/stream/heartbeat fixes are rejected when their timestamp is stale rather than being re-stamped as fresh.
- The map clearly tells web users that sharing stops when the tab is closed, and compact screens can switch between a full map and a full-height People list.
- The profile screen and in-app notification feed use clearer identity, privacy and activity cards.
- Notification preference saves are serialized; controls are disabled during writes and local choices roll back if a save fails.
- History restoration retries after a transient Firestore read failure instead of permanently proceeding without the existing daily track.
- Travel History has quick local-date shortcuts and a day-at-a-glance panel for recorded stops, simplified route-point count and last accepted location-fix time. It is derived from the selected member/day track and does not add database reads or writes.
- Travel History's stop timeline now uses cards with arrival/departure time chips, stay duration and an OPEN/last-seen state that avoids claiming stale history is current; the route map adds a fit-to-route action. These controls operate on the currently loaded track only.
- Tightened Firestore location authorization: active-sharing query marker, direct-read consent check, atomic location deletion for pause/stop/removal, and parent-circle existence checks against orphaned child data.
- Circle-shared travel history now requires the user's master “Keep my travel history” setting for both Firestore reads and writes. Turning that setting off blocks subsequent server-side reads of existing circle copies even if per-circle sharing remains on; already cached data on a recipient's device cannot be remotely recalled.
- Added rules regression tests for pause/stop-without-delete, legacy locations, orphaned data and parent-circle deletion; the manual CI workflow now includes a Firestore Emulator test job.
- Fixed place-alert restoration so the latest departure resets stale “inside” state; added a regression test for the next visit.
- Places display used capacity and whether their arrival/departure alerts are enabled.
- Saved Places summarizes alert coverage per circle, filters by alert state, combines name search with alert filters, and supports one-tap pause/resume. A separate persisted pause flag preserves each user's exact arrival/departure choices and member selection while paused; legacy records without the flag default to unpaused. Alert preference controls and Save now remain disabled in edit mode until the existing preference read succeeds, preventing a transient read failure from overwriting preferences with defaults. Alerts remain per-user and in-app only.
- The activity feed supports local search by event text, circle name or category and can be filtered to all events, place alerts, people/membership events, location/sharing events, or manual check-ins. Results are grouped by local date (Upcoming, Today, Yesterday, Last 7 days, Earlier) with per-section counts. Check-ins are self-reported statuses without GPS coordinates; push-notification availability is unchanged.
- Place-alert listeners now use generation guards when sharing scope changes and discard queued events for circles that stop sharing, avoiding stale listeners/events after pause or revoke.
- Circle deletion removes location projections before deleting member documents in small batches to stay within Firestore security-rule access-call limits.
- Account deletion now cleans large sets of a user's place events, place subscriptions, history copies, and join requests in batches of 400 writes; it keeps live-location deletion and membership removal in one atomic batch, and retains master history day keys until reachable circle copies have been processed so interrupted cleanup can be retried more safely.
- Sharing heartbeats use the current session generation across circle switches; late upload responses or delayed errors from an old native stream cannot replace or stop the newer session.
- Pending place events retry the member-name lookup after connectivity recovers instead of remaining stuck until sharing is toggled.
- Pinned Flutter **3.47.2** in `app/.fvmrc`; CI and the Cloudflare build read the same pin. Cloudflare rejects a stale/mismatched SDK instead of silently reusing it.
- Aligned generated Android Gradle settings through `tools/apply_platform_config.py` with AGP **9.4.0**, Gradle **9.8.0**, Kotlin **2.4.10**, Java/JVM target **17**, and Google Services plugin **4.5.0** when present. The native project is generated locally, so this still requires a real generated Android build.

- Added one active expected-arrival plan per member and circle, reschedulable to another saved place. Other circle members see an in-app "no arrival recorded" warning after the deadline; device-recorded late arrivals are shown in the feed. Warnings are computed in-app; there is no server scheduler, push delivery, or background guarantee.

- Added curated one-tap Quick Notes in the map check-in sheet and in-app feed; Firestore Rules restrict values to approved emoji/text pairs, and notes contain no location coordinates. Test status remains not run.

## Improvement added in this branch

- Automatic Place Suggestions are now implemented in code behind two separate opt-ins: private Travel History and Place Suggestions. A bounded query reads only the signed-in user's history within the 7/30/90-day retention window. Suggestions are calculated locally from unlabeled stops recurring on at least three days, remain dismissible in the current view, and open the normal place editor for review. Candidate coordinates are not uploaded or saved until the user saves a place to the selected circle. Tests are authored but not run.

- Added per-circle Approximate Location/Bubble with 1/4/8-hour expiry, a visible coarse-pin radius and label, direction handoff disabled while approximate, and Firestore Rules that reject precise location writes during an unexpired Bubble. Expiry is client-driven: it resumes precise sharing while the app is running or on the next sync after reopen; there is no server scheduler. Place alerts, check-ins and separately shared history remain independent.

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
