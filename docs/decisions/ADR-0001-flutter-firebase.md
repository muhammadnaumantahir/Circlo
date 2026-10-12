# ADR-0001: Flutter + Firebase for MVP
**Status:** Proposed
**Context:** Needs Android+iOS, small team, realtime updates, limited budget/ops capacity.
**Options:** (A) Flutter+Firebase; (B) Flutter+Supabase/Postgres; (C) Native x2 + custom backend.
**Decision:** A, as in the owner's document.
**Rationale:** Fastest path, managed auth/push/realtime, serverless ops.
**Consequences:** Usage-based cost scales with writes; vendor lock-in; geo/history queries are limited versus PostGIS — revisit if history volume/costs exceed targets.
