# Repository Review — 2026-10-13

**Scope:** Static review of the planning documents on the default branch. This repository currently contains planning artifacts only; there is no application code to build or test. No runtime behavior has been verified.

## Summary

The requirements and privacy-first direction are solid. Keep this as a planning baseline until the owner approves the open decisions and the technical spikes pass. The most important unresolved item is the authentication boundary between Firebase Auth and Supabase under a strict $0/no-billing constraint.

## Findings and required actions

### P0 — Prove the Firebase Auth → Supabase path before implementation

The architecture uses Firebase Auth for sign-in and Supabase for the database, RLS, Realtime, Storage, and Edge Functions. Supabase's official Firebase integration guide says Firebase JWTs need the `role: authenticated` claim for the usual authenticated database policies. Its documented ways to assign that claim use Firebase Cloud Functions or Identity Platform features, which conflict with the current rule that Firebase stays on Spark and no billing account is linked.

This is a **design risk, not proof that integration is impossible**. Before building features, run a small spike that proves a newly registered user can securely read/write a test row through Supabase RLS without paid Firebase services. Do not solve this by exposing a service-role key or disabling RLS.

**Recommended fallback:** use Supabase Auth for both login and database identity, while retaining Firebase Cloud Messaging only for push. Confirm email/password, password-reset delivery limits, and account deletion on the free plan before deciding.

Official reference: https://supabase.com/docs/guides/auth/third-party/firebase-auth

### P1 — Make circle-scoped location authorization explicit

The data model has one `live_locations` row per user, while location-sharing permission is stored per circle in `circle_members.shares_location`. RLS must check the relationship between the viewer, the location owner, and the exact circle—not merely that both users belong to some circle. Apply the same principle to historical points, visits, place events, and Realtime subscriptions.

Add automated tests for:
- A member of Circle A cannot read location/history shared only with Circle B.
- Paused or revoked sharing blocks new reads and writes as designed.
- Leaving/removal immediately blocks current and historical reads.
- Unauthenticated requests and tokens from a different Firebase project are denied.

### P1 — Treat device-generated place events as untrusted input

Device-side geofence evaluation is a sensible quota-saving approach, but a modified client can fabricate arrival/departure events. Enforce authenticated ownership, circle membership, place subscription, timestamp bounds, event rate limits, and plausible transitions server-side. A unique constraint only makes retries idempotent when the same event identifier is reused; generate and persist a stable event/idempotency key for each transition, and test process restarts and retries.

Do not claim alerts are tamper-proof. Clearly handle missed events when the OS suspends or kills the app.

### P1 — Test background location before committing to reliability targets

The Android, iOS, and web requirements are not equivalent. Web cannot provide continuous background tracking after a tab is closed. Android background behavior varies by permission state and device power management; iOS has its own permission and execution limits. Keep the web limitation visible, and make an Android real-device spike the first platform test. Treat the proposed battery and alert-delivery targets as goals until measured.

### P1 — Make the zero-cost map plan policy-compliant

OpenStreetMap data is open, but the public OSM tile servers and public geocoding services are not unlimited production APIs. Keep the tile/geocoder provider configurable, display attribution, follow caching and identification requirements, avoid bulk/offline tile downloads, and obey the geocoder's own policy. Do not assume a public endpoint is guaranteed or suitable for growing traffic.

Official tile policy: https://operations.osmfoundation.org/policies/tiles/

### P2 — Clarify data lifecycle and privacy decisions

Before launch, decide the minimum age and launch markets, and obtain appropriate review for minors' data and privacy obligations. Make sure retention cleanup covers both raw location points and derived visits, and that account deletion removes storage files, notification records, device tokens, and circle-owned data according to the ownership-transfer rule.

### P2 — Remove assumptions that promise free-tier availability

Do not rely on a keep-alive job as a guarantee that a free backend will remain available. Document possible pause/quota outages, monitor usage, provide a clear “sync delayed/unavailable” state, and test recovery after a pause. Confirm current limits in the provider console before release.

## Suggested next steps

1. Resolve the authentication spike without enabling billing.
2. Confirm the open product decisions in `requirements.md` §13, especially distribution, minimum age, launch markets, and join approval defaults.
3. Implement the smallest vertical slice: sign-in → profile → create/join circle → RLS-protected membership.
4. Add security tests before adding live location data.
5. Prove Android background tracking and device-side place detection on real phones.
6. Only then approve the wider MVP implementation.

## References checked

- Supabase Firebase Auth integration: https://supabase.com/docs/guides/auth/third-party/firebase-auth
- Supabase third-party auth overview/pricing: https://supabase.com/docs/guides/auth/third-party/overview
- Firebase pricing (Spark/FCM): https://firebase.google.com/pricing
- OpenStreetMap tile usage policy: https://operations.osmfoundation.org/policies/tiles/
