# ADR-0002: Place arrival/departure detection on the member's device, de-duplicated on the server
**Status:** Proposed (supersedes the earlier "server-side evaluation" draft; owner delegated this decision)
**Context:** Server-side evaluation of every location update needs Cloud Functions (not free) or would burn free Edge Function/Realtime quotas. OS geofences have per-app region limits (iOS notably low).
**Options:** (A) Server evaluates every update; (B) OS geofences on each phone; (C) App evaluates its own location against synced place list, sends only events.
**Decision:** C.
**Rationale:** Near-zero server load; no OS region limit; works with the free tier; simple server-side dedup via unique constraint.
**Consequences:** Depends on background location reliability (ADR-0003); a modified client could send false events about *itself* (accepted, mitigated by validation/rate limits); web only while tab open.
