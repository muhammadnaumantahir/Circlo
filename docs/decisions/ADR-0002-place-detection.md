# ADR-0002: Place arrival/departure detection on the member's device, with trusted validation when available
**Increment 3 implementation note (2026-10-13):** `PlaceDetector` (pure, tested) + `PlaceAlertEngine`; arrival needs 2 consecutive fixes inside the radius, departure 2 consecutive fixes beyond radius × 1.2, accuracy ≤100 m; event document id = `memberUid_placeId_visitId_type` (idempotent); "inside" state is restored from the member's own latest events after a restart. Alerts reach others only through the in-app feed (remote push deferred by owner decision). Not verified on real devices.
**Status:** Proposed (owner delegated this decision)
**Context:** Server-side evaluation of every location update needs trusted server infrastructure, which is not approved under the strict no-billing Spark constraint. OS geofences have per-app region limits (iOS notably low).
**Options:** (A) Server evaluates every update; (B) OS geofences on each phone; (C) App evaluates its own location against synced place list and sends event records.
**Decision:** C.
**Rationale:** Reduces server work and avoids OS region limits; fits the intended free-tier approach.
**Consequences:** Depends on background location reliability (ADR-0003). A modified client can forge events; client-side debounce and stable event IDs help but do not replace trusted validation. Do not trigger cross-user remote push from untrusted events until a secure server path exists. Web detection works only while the tab is open.
