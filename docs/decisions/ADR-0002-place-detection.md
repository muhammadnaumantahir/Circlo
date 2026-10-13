# ADR-0002: Place arrival/departure detection on the member's device, with trusted validation when available
**Status:** Proposed (owner delegated this decision)
**Context:** Server-side evaluation of every location update needs trusted server infrastructure, which is not approved under the strict no-billing Spark constraint. OS geofences have per-app region limits (iOS notably low).
**Options:** (A) Server evaluates every update; (B) OS geofences on each phone; (C) App evaluates its own location against synced place list and sends event records.
**Decision:** C.
**Rationale:** Reduces server work and avoids OS region limits; fits the intended free-tier approach.
**Consequences:** Depends on background location reliability (ADR-0003). A modified client can forge events; client-side debounce and stable event IDs help but do not replace trusted validation. Do not trigger cross-user remote push from untrusted events until a secure server path exists. Web detection works only while the tab is open.
