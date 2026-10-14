# Risk Register (DRAFT v0.3 — Firebase-only)

| ID | Risk | Impact | Mitigation | Decision needed |
|---|---|---|---|---|
| R-01 | Background location killed by OS/OEM battery managers | High | Early spike (ADR-0003), foreground service, user guidance, device matrix | Plugin choice (free) |
| R-02 | Store rejection for background location | High | Clear disclosure, justification text, privacy labels | — |
| R-03 | Privacy misuse (stalking/coercion) | High | Transparency, notifications on sharing, easy exit, abuse reporting | Report/block scope |
| R-04 | **Firestore free quotas exceeded** (reads/writes/storage/network) | High: service degrades/stops | Throttle location writes, limit listeners/reads, prune history, check usage weekly, graceful degradation; design for small groups | Accept small scale? |
| R-05 | Duplicate/missed place alerts (GPS jitter, device asleep) | Medium | Hysteresis, debounce, unique-constraint dedup, simulated-track tests | — |
| R-06 | **Minors/legal compliance** (COPPA/GDPR-K, store kids policies) | High | Minimum age, minimal data, legal review before launch | Q2b, Q3 |
| R-07 | Firestore Rules gaps expose locations | High | Default deny, automated Firestore Emulator Rules tests in CI | — |
| R-08 | Battery drain | Medium | NFR-004, adaptive sampling | — |
| R-09 | iOS/Play distribution needs paid accounts | Medium | Android APK + web first; iOS later | Q1b |
| R-10 | Plan details/versions/policies unverified or changing | Medium | Verify in official docs/console before building | — |
| R-11 | No trusted server automation under Spark/no billing | Medium | Do not expose credentials; defer server-dependent features or obtain owner approval for an alternative | — |
| R-12 | Free map tile/geocoder terms or limits forbid app use | Medium | Spike (ADR-0004); fallback to pin-drop only | — |
| R-13 | Web cannot track in background → inconsistent expectations | Low–Medium | Clear web banner, docs | — |
| R-14 | Firebase Spark cannot run trusted Cloud Functions for remote push/privileged workflows | Medium | P0 blocker: prove a secure no-cost server path or defer remote push and server-side maintenance | Q11 |
| R-15 | Forged place events from modified clients | High | Treat client events as untrusted; do not trigger remote alerts until trusted validation exists | — |
| R-16 | No trusted server-side FCM sender on Spark/no billing | High / launch blocker | Never embed FCM server credentials; prove an approved secure server option or explicitly defer remote push | Owner approval required |
| R-17 | Firestore Rules cannot safely express intended cross-circle reads | High | Prototype rules in Emulator; use circle-scoped projections or revise data model if authorization cannot be proven | Security spike |


## Increment 5 additions
- **Account/circle deletion is best-effort and client-side.** It cannot list other people's data about you (for example orphaned history copies in a circle you were removed from) and an interrupted run leaves partial deletion; re-running completes it. Needs privacy/legal review (GDPR erasure) before launch.
- Deleting a circle costs many writes (members × places subscription ids, plus 93 history ids per member who shared history).
- Approval flow needs the requester's app to be opened after approval to finish joining (no server to create the membership).
- A requester cannot read the circle, so the app tries an open join first and falls back to a request; error messages stay generic on purpose.
- Email verification: users on the Auth emulator must fetch the verification link from the emulator; the ID token must be force-refreshed after verifying (handled in the app).

## Increment 4 additions
- **Retention is best-effort**: cleanup runs on the user's own device (when the History tab opens or retention changes). If a user stops opening the app, old days remain until then; copies in circles stay unreadable once history/location sharing is switched off, but data is not physically removed. Without a server or billing this cannot be guaranteed (owner-accepted scope; legal/privacy review needed before launch).
- Removing a member or deleting a circle can leave orphaned history copies (the owner cannot list them). They are unreadable after membership ends.
- History is recorded only while sharing runs and the app/service receives fixes; gaps are expected. A visit that spans midnight is split at the day boundary. Unnamed stops show "Unknown place" (no reverse geocoding, to respect free limits).
- Each flush writes 1 master + N circle documents (≈ every 5 min while moving, plus on visit changes): watch the free write quota.
- History reveals routines (home/work): shown only by opt-in, per person, per circle; minors default off. Needs privacy review.

## Increment 3 additions
- Alerts are **in-app only** (owner-accepted scope): a viewer sees an arrival/departure only while their app is open and syncing; nothing reaches a closed app.
- Events are client-created and untrusted; rules bind them to the actor, sharing state, place and names, but cannot prove the position was real. Impact is limited to that member's own events.
- Event documents are never cleaned up automatically (no server); members may delete only their own. Growth is bounded by small groups; revisit if quota is a problem.
- Free geocoder (Nominatim) policy: ≤1 request/s, no autocomplete, attribution; not for heavy use (ADR-0004). Tap-to-pin always works as a fallback.
- Place limit (20 per circle) is a client-side check only.
- Each place event restore query and each feed listener consumes free-tier reads; watch quota.

## Increment 2 additions
- Circle-scoped location copies cost N writes per update against the Firestore free quota (verify limits); throttled to ≥30 s plus a 5-minute heartbeat. Revocation deletes the copy atomically; if the device is offline at that moment the copy remains until the next successful write and is shown as "Location unavailable" after 10 minutes.
- Background sharing is unverified on real devices (ADR-0003).
- Default OSM tile server is for development only (ADR-0004).
