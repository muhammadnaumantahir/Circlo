# Roadmap (DRAFT v0.3 — Firebase-only)
## MVP (v1.0) — reduced scope (owner decision 2026-10-13: no server-dependent features)
0. **Blocking spikes before full implementation:** Firestore Rules for circle-scoped location access; safe circle/join-code operations without trusted functions; secure zero-cost server path for remote FCM and cleanup (or explicitly defer those features); Android/iOS background tracking on real devices (ADR-0003); free maps/geocoder (ADR-0004); Firestore quota model.
1. **Foundation + core:** repo/CI, auth, profiles + age gate, circles, join codes, member management.
2. **Live locations:** map, sharing controls, statuses, permissions, web view.
3. **Saved places:** place search/pin, device-side detection, dedup, push.
4. **Travel history:** points, visits, timeline, route, controls, retention.
5. **Hardening & release:** Firestore Security Rules Emulator tests, battery tuning, accessibility, privacy policy review, Android APK + web release.
## Later (not approved)
iOS/Play distribution (needs paid accounts), driving/trip detection, low-battery alerts, SOS, check-in, speed alerts, data export, report/block tooling, localization, paid scale-up plan.

- Increment 3 done in code: saved places, alert preferences, in-app arrival/departure feed.
- Increment 4 done in code: opt-in travel history with daily compact documents, per-circle sharing, client-side retention/deletion.
- Increments 5–6 done in code: circle lifecycle (verification, approval, transfer, deletion, account deletion best-effort) and notifications/polish.
- Expected-arrival/No Show v1: saved-place deadline commitments, in-app overdue warnings for other circle members, and late-arrival status when tracking confirms it; evaluation is client-side and only while the app is open. Reliable background scheduling and phone push remain deferred.
- Next: hardening/release prep (first CI run + fixes, real-device test matrix, accessibility pass, privacy/legal review, replace free map/geocoder providers, store prep).

## Deferred until a trusted no-cost server exists
Remote cross-user push (arrival/departure and membership alerts), scheduled retention cleanup, complete recursive account/circle deletion guarantee, server-validated place events.
