# Circlo — Requirements Baseline (DRAFT v0.3)

**Owner decisions 2026-10-12/13:** Flutter app for web + Android + iOS · minors may use the app · monthly budget **$0**, no billing account · Firebase-only backend (Authentication + Cloud Firestore + FCM) · history opt-in, 30-day default retention · device-side place detection · native background location when permitted, including screen-locked operation. Web cannot track after its tab closes. Trusted server-side push/automation remains a blocking design issue under Spark/no-billing.

Legend: **[C]** = confirmed from owner's requirements document · **[R]** = recommended by analyst, needs approval · **[A]** = assumption.
Priority: **Must / Should / Could / Not in this release**.

## 1. Vision, problem, goals, users, metrics
- **Vision:** Private, consent-based location sharing for families and friends.
- **Problem:** Families need to know where loved ones are and when they arrive/leave key places, without privacy loss.
- **Goals:** Trustworthy location sharing; useful alerts; user control over data.
- **Users:** Circle owners (create/manage), circle members (share/view), guardians (place alerts).
- **Success metrics:** see [PROJECT_BRIEF.md](PROJECT_BRIEF.md) (proposed targets, need approval).

## 2. Scope
**In scope (MVP):** Accounts, circles, join codes, live map, sharing controls, saved places & alerts, travel history, notifications, privacy controls (source phases 1–5).
**Out of scope / Not in this release [C]:** driving/trip detection, low-battery alerts, SOS button, check-in button, speed alerts. **[R]** also out: in-app chat, payments/subscriptions, social login, analytics/ad SDKs, sharing with non-app users, any paid cloud service.

## 3. Functional requirements

### 3.1 User accounts
| ID | Requirement | Pri |
|---|---|---|
| FR-001 | User can sign up with email + password. [C] | Must |
| FR-002 | User can log in and log out; session persists across app restarts until logout. [C] | Must |
| FR-003 | User can reset password via emailed link. [C] | Must |
| FR-004 | User can set display name (required), profile picture (optional), phone number (optional). [C] | Must |
| FR-005 | User can view and manage location permission status, with a shortcut to OS settings. [C] | Must |
| FR-006 | User can delete their account; all personal data, memberships, location data and history are deleted (see NFR-012). [C] | Must |
| FR-007 | Email verification required before joining/creating circles. [R] | Should |

### 3.2 Circles
| ID | Requirement | Pri |
|---|---|---|
| FR-010 | User can create a circle with name (required) and picture (optional); creator becomes Owner. [C] | Must |
| FR-011 | System generates a unique, hard-to-guess join code per circle (≥8 chars, unambiguous alphabet). [C][R] | Must |
| FR-012 | Owner can share the code (OS share sheet/copy). [C] | Must |
| FR-013 | User can join by entering a valid code; invalid/expired/revoked codes show a clear error. [C] | Must |
| FR-014 | Owner can enable "approval required"; then join creates a pending request that Owner accepts/rejects. [C] Default off. [A] | Should |
| FR-015 | User can belong to multiple circles. [C] | Must |
| FR-016 | User can see the member list of each circle (name, photo, role). [C] | Must |
| FR-017 | Owner can remove members; removed member immediately loses access to the circle's data. [C] | Must |
| FR-018 | Owner can transfer ownership to another member, or delete the circle (with confirmation). [C] | Must |
| FR-019 | Any member can leave a circle at any time; access revoked immediately. [C] | Must |
| FR-020 | Owner can revoke/regenerate the join code and optionally set an expiry. [C] | Must |
| FR-021 | A circle member limit applies (proposed 20). [A] | Should |
| FR-022 | If the Owner deletes their account, ownership must be transferred or the circle deleted first. [R] | Must |

### 3.3 Live location
| ID | Requirement | Pri |
|---|---|---|
| FR-030 | Map shows circle members with name, photo, current/last location. [C] | Must |
| FR-031 | Each member shows "last updated" time (relative + absolute on tap). [C] | Must |
| FR-032 | Each member shows status: Sharing/Online, Paused, Location unavailable (permission off / no connectivity / stale), Not sharing with this circle. [C] | Must |
| FR-033 | App updates location in background when permitted, adaptively (moving vs. stationary). [C] | Must |
| FR-034 | User can pause/resume sharing globally; pause takes effect immediately. [C] | Must |
| FR-035 | User chooses per circle whether it can see their location. [C] | Must |
| FR-036 | Before first sharing, user sees a plain-language consent screen explaining what is shared, with whom, and how to stop. [C][R] | Must |
| FR-037 | While sharing in background, a persistent visible indicator is shown (Android foreground notification; iOS system indicator). Hidden tracking is prohibited. [C] | Must |
| FR-038 | Optional: pause for a fixed duration (1h / until tomorrow). [R] | Could |

### 3.4 Places and alerts
| ID | Requirement | Pri |
|---|---|---|
| FR-040 | User can search for a place (address/name) on the map using a free geocoder (rate-limited, cached); fallback: drop a pin. [C][A] | Must |
| FR-041 | User can select a location and save it with custom name. [C] | Must |
| FR-042 | User sets radius (proposed range 100 m–1 km, default 150 m). [C][A] | Must |
| FR-043 | User can edit/delete saved places. [C] | Must |
| FR-044 | User can enable/disable alerts per place. [C] | Must |
| FR-045 | User receives a notification when a chosen member arrives at a saved place. [C] | Must |
| FR-046 | User receives a notification when a chosen member leaves a saved place. [C] | Must |
| FR-047 | User chooses which members' alerts to receive (per place). [C] | Must |
| FR-048 | No duplicate notifications for the same visit (state machine + debounce, see architecture §7). [C] | Must |
| FR-049 | Saved places are visible only to the circle they belong to; a place belongs to one circle. [A] | Must |
| FR-050 | Only members who share location with that circle can trigger alerts; members are told when a place alert applies to them. [R] | Must |
| FR-051 | Maximum saved places per circle (proposed 20). [A] | Should |

### 3.5 Travel history
| ID | Requirement | Pri |
|---|---|---|
| FR-060 | Authorized user can view a member's history on a map for a selected date. [C] | Must |
| FR-061 | Show visited places with approximate arrival/departure times. [C] | Must |
| FR-062 | Show stay duration per place. [C] | Must |
| FR-063 | Show travelled route where sufficient points exist; otherwise show "insufficient data". [C] | Should |
| FR-064 | Show daily timeline (see example in source doc §5). [C] | Must |
| FR-065 | Each user controls whether their history is shared (off by default). [C][R] | Must |
| FR-066 | User can delete own history (all or by date range). [C] | Must |
| FR-067 | Configurable retention period (options 7/30/90 days; default 30). [C][A] | Must |
| FR-068 | Unnamed stops are shown as "Unknown place" with coordinates/address (reverse geocoding cost TBD). [A] | Should |

### 3.6 Map and member details
| ID | Requirement | Pri |
|---|---|---|
| FR-070 | One map showing all members of the selected circle. [C] | Must |
| FR-071 | Tap member → detail sheet (current/last location, last update, status). [C] | Must |
| FR-072 | "Get directions" opens the device/web maps app to the member's location (no in-app navigation; keeps cost at $0). [C][A] | Should |
| FR-073 | Saved places drawn on map with radius. [C] | Must |
| FR-074 | User can switch between circles. [C] | Must |

### 3.7 Notifications
| ID | Requirement | Pri |
|---|---|---|
| FR-080 | Notify: member joined; new join request/invitation; arrived; left; sharing stopped/unavailable; membership changes; account/security events. [C] | Must (arrive/leave, join, security); Should (others) |
| FR-081 | User can enable/disable each notification type (and per circle). [C] | Must |
| FR-082 | In-app notification list with read state, retained 30 days. [A] | Must |
| FR-083 | "Sharing unavailable" alert fires only after ≥15 min stale and at most once per outage. [R] | Should |
| FR-084 | Push permission requested in context, with in-app fallback when denied. [R] | Must |

### 3.8 Platforms, web and minors (new, from owner decisions)
| ID | Requirement | Pri |
|---|---|---|
| FR-100 | One Flutter codebase builds for web, Android and iOS. [C] | Must |
| FR-101 | Web app: sign in, view circles/map/places/history, manage settings; shares location **only while the tab is open** and tells the user that background sharing is unavailable on web. [R] | Should |
| FR-102 | Age declaration at sign-up (age band/birth year). Users below the minimum age (proposed 13, region-dependent) cannot register. [A] | Must |
| FR-103 | Minor users get plain-language consent text; may pause/leave any time; history sharing off by default. [R] | Must |
| FR-104 | When a minor pauses sharing or leaves a circle, the circle owner is notified. [R] | Should |
| FR-105 | Place arrival/departure is detected on the sharing member's device and de-duplicated on the server (ADR-0002); events are not generated while sharing is paused. [A] | Must |

### 3.9 Privacy & security (functional)
| ID | Requirement | Pri |
|---|---|---|
| FR-090 | Only current members of a circle can read data shared to that circle. [C] | Must |
| FR-091 | Users can see who currently can view their location ("Who sees me"). [R] | Must |
| FR-092 | Leaving/removal revokes access to current and historical data of that circle immediately. [C] | Must |
| FR-093 | Data-export (download my data). [R] | Could |
| FR-094 | Notify a user when they are added to a circle or when sharing is turned on for a circle. [R] | Must |

## 4. Non-functional requirements
| ID | Requirement (measurable) | Pri |
|---|---|---|
| NFR-001 | Location updates visible to other members within 30 s of device upload when online (p95); upload cadence is throttled to fit free quotas, so "live" may mean updates every 15 s–5 min. [R target] | Must |
| NFR-002 | Arrival/departure alert within 2 min of event (p90) in field tests. [R target] | Must |
| NFR-003 | Map screen interactive in ≤3 s on mid-range device on 4G (p90). [R target] | Should |
| NFR-004 | Battery: background sharing ≤5%/day on reference devices. [R target, validate] | Should |
| NFR-005 | All traffic over TLS; data encrypted at rest (managed provider default). | Must |
| NFR-006 | Authorization enforced server-side (security rules/functions), never only in client; automated rule tests cover every collection. | Must |
| NFR-007 | Platforms: Android 8.0+ (API 26+), iOS 15+, and current evergreen browsers (Chrome, Edge, Firefox, Safari). [A] | Must |
| NFR-008 | Accessibility: WCAG 2.1 AA targets, screen-reader labels, text scaling to 200%, 4.5:1 contrast, non-color-only status. | Should |
| NFR-009 | Offline: show last known data with "offline" banner; queue location uploads up to 24 h. | Should |
| NFR-010 | Localization: English only for MVP; strings externalised. [A] | Must |
| NFR-011 | Join-code guessing protected by rate limiting (e.g. 10 attempts/hour/user) and free abuse protection (e.g. Firebase App Check, if available on the free plan). | Must |
| NFR-012 | Account deletion removes all user-owned data within 30 days (target: immediate; backups ≤30 d). | Must |
| NFR-013 | Crash-free sessions ≥99.5%. [R target] | Should |
| NFR-014 | Compliance: privacy policy, store data-safety/privacy labels, GDPR-style rights; minors' handling per open question Q2. Legal text requires owner/lawyer approval. | Must |
| NFR-015 | **Monthly cost = $0.** No billing account linked to Firebase/Google Cloud; only free tiers; app degrades gracefully when free quotas are hit; weekly usage check. [C] | Must |
| NFR-016 | Free-tier limits respected: DB ≤ ~400 MB soft cap with pruning, throttled location uploads, Firestore quota monitoring and graceful degradation. | Must |

## 5. Use cases / acceptance criteria (key)
- **UC-1 Join circle (FR-013):** Given a valid code, when entering it, then user appears in member list and owner is notified; given an expired/revoked code, then a non-revealing error is shown and no membership is created.
- **UC-2 Pause sharing (FR-034):** Given sharing is on, when user taps Pause, then within 30 s others see "Paused" and no new points are stored.
- **UC-3 Arrival alert (FR-045/048):** Given a place with alert enabled, when a member enters the radius and stays ≥2 min, exactly one "arrived" notification is sent per visit; GPS jitter at the boundary does not create repeats.
- **UC-4 History (FR-060–065):** Given the member shares history, selecting a date shows chronological visits with durations; given they do not, the viewer sees "History not shared".
- **UC-5 Leave circle (FR-019/092):** After leaving, user can no longer read circle data (verified by security-rule test).
- **UC-6 Delete account (FR-006):** After deletion, user's profile, locations, history, memberships, tokens are removed; owned circles handled per FR-022.

## 6. Business rules & validation
- Name 1–50 chars; circle name 1–40; phone E.164 format optional; password ≥8 chars (provider rules); image ≤5 MB, JPEG/PNG, resized client-side.
- A circle always has exactly one Owner. Owner cannot leave without transfer/delete.
- A member must be sharing to a circle to appear on its map; viewing requires membership only.
- A user cannot view their own alerts for themselves.

## 7. Required UI states
Every data screen defines loading, empty, error, offline, timeout, permission-denied (location, notifications), success. See [design/screen-specification.md](design/screen-specification.md).

## 8. Data
Inputs: profile, circle data, locations (lat, lon, accuracy, timestamp, battery-optional **not** collected), places. Outputs: map views, notifications, timelines. Retention: live location = latest only; history per FR-067; notifications 30 d. Deletion per FR-006/066/NFR-012.

## 9. External integrations
Firebase Authentication + Cloud Firestore + Firebase Cloud Messaging on Spark, within free quotas; OSM-based map tiles + a free geocoder subject to provider policies. Cloud Functions are not available on Spark. Consequently, secure server-triggered cross-user push, scheduled retention cleanup, and trusted enforcement for sensitive operations need a separate approved solution before those features can be production-ready.

## 10. Constraints & dependencies
$0 budget with no billing account; Firebase Spark quotas; Cloud Functions require Blaze; OS background-location policies; web cannot track in background; Apple Developer (paid) account needed to distribute iOS apps and Google Play has a developer fee (outside budget → see Q1); store review of background location; map/geocoder provider limits.

## 11. Priorities summary
Must: auth, circles, join codes, map + consent/pause, places + alerts, history + controls, privacy rules. Should: approval flow, route display, email verification. Could: data export, timed pause.

## 12. Assumptions
Listed inline with [A]. Notable: single Owner role (source uses both "creator" and "owner" → treated as same); places belong to one circle; English only; Android 8+/iOS 15+.

## 13. Decisions and open questions
**Decided by owner (2026-10-12)**
| # | Topic | Decision |
|---|---|---|
| Q1a | Platforms | Flutter for web, Android, iOS |
| Q2a | Minors | Allowed |
| Q4 | Budget | $0; Firebase-only architecture on Spark/free quotas; no billing account |
| Q5/Q6 | History | Opt-in per person; 30-day default retention |
| Q10 | Place detection | Analyst's choice → device-side detection + server dedup (ADR-0002) |

**Still open**
| # | Question | Recommended default |
|---|---|---|
| Q1b | iOS distribution needs a paid Apple Developer account (~$99/yr) and Google Play has a one-time fee; both conflict with $0. Distribute Android via APK/GitHub Releases and web for free, add iOS/Play when budget exists? | Yes; keep code iOS-ready |
| Q2b | Minimum age: 13? "Minors allowed" cannot cover under-13 without verifiable parental consent (not feasible at $0) | 13+ (16 where required); legal review before launch |
| Q3 | Launch countries/markets (privacy law depends on it) | Decide before privacy policy |
| Q7 | Join "approval required" default | Off, owner can enable |
| Q8 | History visibility | Each person decides (FR-065) |
| Q9 | Deadline / target launch date | — |
| Q11 | Server-side push/automation under Firebase Spark without a billing account | Unresolved blocker; do not expose credentials or claim full remote alerts work until a secure solution is proven |
| Q12 | Should owners be notified when a minor pauses sharing (FR-104)? | Yes |

## 14. MVP completion criteria
All Must requirements pass acceptance tests ([docs/test-plan.md](docs/test-plan.md)); security-rule tests pass; field test of alerts on ≥2 Android and ≥2 iOS devices; store privacy declarations ready; owner signs off on documented exceptions.
