# Project Status

- **Current phase:** Phase 5 — Firebase-only baseline revised (v0.3), **awaiting owner approval**.
- **Approved baseline:** None yet. Approval date: _pending_.
- **Implementation code:** None. No application coding until explicit approval.
- **Last updated:** 2026-10-13.

## Owner decisions (2026-10-12/13)
- Flutter app for web, Android and iOS.
- Minors may use the app (minimum age and legal review still open: Q2b).
- Monthly budget $0 with no billing account; Firebase-only stack: Authentication + Cloud Firestore + FCM.
- Native Android/iOS should attempt background location while the screen is locked, subject to OS permissions and restrictions; web only while tab is open.
- Travel history opt-in; 30-day default retention.
- Place detection runs on-device; event validation/deduplication needs a trusted processing path.

## What changed in v0.3
Owner selected Firebase-only: Authentication + Cloud Firestore + FCM; the prior database/backend option has been removed. Native Android/iOS background tracking should continue with the screen locked when permissions and OS policies allow; web remains foreground-tab only. Minor-safety requirements FR-102–104 remain. Free quotas limit scale.

## Review update (2026-10-13)
- Updated architecture, data model, security/privacy, roadmap, requirements, and review findings for Firebase-only.
- **P0 blocker:** Firebase Cloud Functions require Blaze, so trusted remote FCM sending, privileged operations, and scheduled cleanup have no approved server under strict Spark/no-billing. Do not embed server credentials in the app.
- Additional pre-build checks: circle-scoped Firestore Rules, safe join-code/membership flows, real-device background-location tests, and map/geocoder policy compliance.
- No application code was implemented and no build/test run was possible because the repository currently contains planning documents only.

## Planning artifacts
PROJECT_BRIEF.md, requirements.md, architecture.md, design/{design-system,screen-specification,design-prompts}.md, docs/{user-flows,data-model,security-privacy,traceability,risks,roadmap,review-findings}.md, docs/decisions/ADR-0001..0004.

## Not created (and why)
- **design/screens/ images:** no mockup images have been generated yet; prompts are in design/design-prompts.md.
- **docs/api-spec.md, deployment.md, operations.md:** deferred until architecture and server-side push decision are approved.
- **AGENTS.md, docs/test-plan.md, release docs, CI, .env.example:** created after approval (Phases 6–7).

## Unverified items (must verify from official docs before building)
Current Firestore quotas and Rules behavior, trusted no-cost server option for remote push/privileged operations, map tile/geocoder terms, store fees/policies, package versions, and real-device background tracking.

## Outstanding questions
requirements.md §13 (Q1b, Q2b, Q3, Q7, Q8, Q9, Q11, Q12), plus the security, trusted-server, background tracking and map-provider spikes listed in docs/review-findings.md.

## Next steps
1. Resolve the trusted server-side push/privileged-operations blocker without enabling billing, or explicitly defer those features.
2. Prototype Firestore Rules in the Emulator and test circle-scoped access.
3. Verify current provider quotas and map/geocoder terms.
4. Owner approves baseline → date recorded here.
5. Phase 6: repo setup, then the security, background-location, and provider spikes.
