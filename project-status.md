# Project Status

- **Current phase:** Phase 5 — Baseline revised (v0.2), **awaiting owner approval**.
- **Approved baseline:** None yet. Approval date: _pending_.
- **Implementation code:** None. No coding until explicit approval.
- **Last updated:** 2026-10-13.

## Owner decisions (2026-10-12)
- Flutter app for web, Android and iOS.
- Minors may use the app (minimum age and legal review still open: Q2b).
- Monthly budget $0: Firebase for login (and free push) only; other online data on free tiers.
- Travel history opt-in; 30-day default retention.
- Place detection approach delegated → device-side detection + server dedup (ADR-0002).

## What changed in v0.2
Stack moved from Firestore/Cloud Functions/Google Maps (paid or billing-required) to Firebase Auth + free-tier Supabase + OSM-based maps. Web added (view-only background). Minor-safety requirements FR-102–104 added. Capacity is limited to small groups by free-tier quotas.

## Planning artifacts
PROJECT_BRIEF.md, requirements.md, architecture.md, design/{design-system,screen-specification,design-prompts}.md, docs/{user-flows,data-model,security-privacy,traceability,risks,roadmap}.md, docs/decisions/ADR-0001..0004.

## Not created (and why)
- **design/screens/ images:** no image-generation tool available; prompts in design/design-prompts.md.
- **docs/api-spec.md, deployment.md, operations.md:** deferred until the architecture is approved (operations list in architecture.md §6).
- **AGENTS.md, docs/test-plan.md, release docs, CI, .env.example:** created after approval (Phases 6–7).

## Unverified items (must verify from official docs before building)
Firebase Spark limits (Functions/Storage on Blaze), Supabase free limits and Firebase-JWT support, map tile/geocoder terms, store fees/policies, package versions.

## Outstanding questions
requirements.md §13 (Q1b, Q2b, Q3, Q7, Q8, Q9, Q11, Q12).

## Next steps
1. Owner reviews and answers open questions.
2. Verification pass (above).
3. Owner approves baseline → date recorded here.
4. Phase 6: AGENTS.md, repo setup, then the four spikes in roadmap.md.
