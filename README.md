# Circlo

Private, consent-based location sharing for families and friends: circles, live map, place arrival/departure alerts, and travel history.

**Status:** Firebase-only planning baseline (no application code yet). See [project-status.md](project-status.md).

## Documentation
- [Project brief](PROJECT_BRIEF.md) · [Requirements](requirements.md) · [Architecture](architecture.md)
- [Repository review findings](docs/review-findings.md) — unresolved technical risks and recommended next steps
- Design: [design system](design/design-system.md), [screens](design/screen-specification.md), [prompts](design/design-prompts.md), [user flows](docs/user-flows.md)
- Docs: [data model](docs/data-model.md), [security & privacy](docs/security-privacy.md), [traceability](docs/traceability.md), [risks](docs/risks.md), [roadmap](docs/roadmap.md), [decisions](docs/decisions/)

Setup, build and test instructions will be added when implementation starts. The current repository is documentation only. Firebase Spark can host Authentication and Firestore within free quotas, but trusted server-side push delivery/automation is a known blocker under the strict no-billing constraint; see [review findings](docs/review-findings.md).
