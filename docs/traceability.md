# Traceability Matrix (DRAFT)

Implementation tasks and test IDs are placeholders to be created in Phase 6/7 (status: **Planned**). Nothing is implemented or tested yet.

| Requirements | Design | Architecture component | Planned task | Planned test |
|---|---|---|---|---|
| FR-001–007 | S1, S2, S8 | Firebase Auth (login), profiles table | T-AUTH | TC-AUTH-* (unit, integration, e2e) |
| FR-010–022 | S4 | circles module, `join_circle` & owner RPCs, join_codes | T-CIRCLE | TC-CIR-* + RLS tests |
| FR-030–038 | S2, S3 | location service, `live_locations` | T-LOC (after ADR-0003 spike) | TC-LOC-* (device field tests) |
| FR-040–051 | S5 | places module, on-device evaluator + `place_events` (ADR-0002) | T-PLACE | TC-PLC-* (simulated tracks, dedup) |
| FR-060–068 | S6 | history module, visit builder, retention cron | T-HIST | TC-HIS-* |
| FR-070–074 | S3 | map module | T-MAP | TC-MAP-* |
| FR-080–084 | S7, S8 | notifications module, FCM | T-NOTIF | TC-NOT-* |
| FR-100–105 | S1, S2, web specifics | Flutter web build, age gate, on-device evaluator (ADR-0002) | T-PLATFORM/T-PLACE | TC-PLAT-*, TC-MIN-*, TC-PLC-* |
| FR-090–094 | S4, S8 | RLS policies, `delete_account` | T-SEC | TC-SEC-* (local-DB RLS tests) |
| NFR-001–004 | — | adaptive location, free-tier throttling | T-PERF | TC-PERF-* |
| NFR-005–006, 011–012, 014 | — | RLS, rate limits, deletion | T-SEC | TC-SEC-* |
| NFR-007–010 | design-system | Flutter app | T-A11Y/T-QA | TC-A11Y-*, device matrix |
