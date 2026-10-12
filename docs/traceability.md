# Traceability Matrix (DRAFT)

Implementation tasks and test IDs are placeholders to be created in Phase 6/7 (status: **Planned**). Nothing is implemented or tested yet.

| Requirements | Design | Architecture component | Planned task | Planned test |
|---|---|---|---|---|
| FR-001–007 | S1, S2, S8 | Firebase Auth, users module | T-AUTH | TC-AUTH-* (unit, integration, e2e) |
| FR-010–022 | S4 | circles module, `joinCircle` & owner functions, joinCodes | T-CIRCLE | TC-CIR-* + rules tests |
| FR-030–038 | S2, S3 | location service, `liveLocations` | T-LOC (after ADR-0003 spike) | TC-LOC-* (device field tests) |
| FR-040–051 | S5 | places module, place engine (ADR-0002) | T-PLACE | TC-PLC-* (simulated tracks, dedup) |
| FR-060–068 | S6 | history module, visit builder, TTL job | T-HIST | TC-HIS-* |
| FR-070–074 | S3 | map module | T-MAP | TC-MAP-* |
| FR-080–084 | S7, S8 | notifications module, FCM | T-NOTIF | TC-NOT-* |
| FR-090–094 | S4, S8 | Security Rules, deleteAccount | T-SEC | TC-SEC-* (emulator rules tests) |
| NFR-001–004 | — | adaptive location, Firestore design | T-PERF | TC-PERF-* |
| NFR-005–006, 011–012, 014 | — | rules, App Check, deletion | T-SEC | TC-SEC-* |
| NFR-007–010 | design-system | Flutter app | T-A11Y/T-QA | TC-A11Y-*, device matrix |
