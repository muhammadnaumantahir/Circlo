# ADR-0002: Server-side arrival/departure detection
**Status:** Proposed
**Context:** Alerts concern *other* members' movements relative to places saved by the viewer. OS geofencing has per-app limits on registered regions (iOS notably low, ~20) and is per-device; places are shared per circle.
**Options:** (A) On-device OS geofences on each member's phone; (B) Server-side evaluation on each location update; (C) Hybrid.
**Decision:** B for MVP.
**Rationale:** No region limits, one source of truth, easy dedup/hysteresis, no extra permissions logic. 
**Consequences:** Requires frequent-enough location uploads near places (higher writes/battery); latency depends on update cadence; add hybrid on-device geofence wake-ups later if battery/latency targets fail. Validate in the background-location spike.
