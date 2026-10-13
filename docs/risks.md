# Risk Register (DRAFT v0.2)

| ID | Risk | Impact | Mitigation | Decision needed |
|---|---|---|---|---|
| R-01 | Background location killed by OS/OEM battery managers | High | Early spike (ADR-0003), foreground service, user guidance, device matrix | Plugin choice (free) |
| R-02 | Store rejection for background location | High | Clear disclosure, justification text, privacy labels | — |
| R-03 | Privacy misuse (stalking/coercion) | High | Transparency, notifications on sharing, easy exit, abuse reporting | Report/block scope |
| R-04 | **Free-tier limits exceeded** (DB 500 MB, realtime messages, connections, edge invocations) | High: service degrades/stops | Throttling, pruning, retention caps, weekly usage check, graceful degradation; design for small groups | Accept small scale? |
| R-05 | Duplicate/missed place alerts (GPS jitter, device asleep) | Medium | Hysteresis, debounce, unique-constraint dedup, simulated-track tests | — |
| R-06 | **Minors/legal compliance** (COPPA/GDPR-K, store kids policies) | High | Minimum age, minimal data, legal review before launch | Q2b, Q3 |
| R-07 | RLS gaps expose locations | High | Default deny, automated RLS tests in CI | — |
| R-08 | Battery drain | Medium | NFR-004, adaptive sampling | — |
| R-09 | iOS/Play distribution needs paid accounts | Medium | Android APK + web first; iOS later | Q1b |
| R-10 | Plan details/versions/policies unverified or changing | Medium | Verify in official docs/console before building | — |
| R-11 | Free backend auto-pauses after inactivity | Medium | Keep-alive cron (verify allowed), status page/banner | — |
| R-12 | Free map tile/geocoder terms or limits forbid app use | Medium | Spike (ADR-0004); fallback to pin-drop only | — |
| R-13 | Web cannot track in background → inconsistent expectations | Low–Medium | Clear web banner, docs | — |
| R-14 | Firebase login ↔ Supabase integration problems | Medium | Spike; fallback Supabase Auth (Q11) | Q11 |
| R-15 | Forged place events from modified clients | Low | Validate membership, rate limit, scope to own events | — |
