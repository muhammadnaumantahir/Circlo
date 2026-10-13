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


## Increment 2 additions
- Circle-scoped location copies cost N writes per update against the Firestore free quota (verify limits); throttled to ≥30 s plus a 5-minute heartbeat. Revocation deletes the copy atomically; if the device is offline at that moment the copy remains until the next successful write and is shown as "Location unavailable" after 10 minutes.
- Background sharing is unverified on real devices (ADR-0003).
- Default OSM tile server is for development only (ADR-0004).
