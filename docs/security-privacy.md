# Security & Privacy (DRAFT)

## Principles
Consent-based, transparent, revocable, least data, default deny.

## Controls
- **Access:** Rules require authentication + membership + share flag. Callable functions validate caller identity and role.
- **Join codes:** ≥8 chars from unambiguous alphabet (~40 bits+), stored server-side only, expiry/revocation, rate limit (NFR-011), no distinction between "not found" and "expired" in errors.
- **Transparency:** consent screen, persistent sharing indicator, "Who sees me", notification when added/shared (FR-036/037/091/094). No stealth mode or hidden app icon.
- **Revocation:** leaving/removal deletes membership doc; rules instantly deny; sharedWith updated.
- **Data minimization:** no contacts, no battery level, no analytics/ad SDKs in MVP.
- **Storage:** managed encryption at rest; TLS in transit; images in Storage with rules by circle membership.
- **Secrets:** none in repo; `.env.example` placeholders only; Maps keys restricted; CI secret scanning.
- **Retention/deletion:** FR-066/067, NFR-012; deleteAccount function purges all user paths, Storage files, FCM tokens, and removes memberships.
- **Abuse:** App Check, per-user rate limits, member/circle caps, report/block mechanism (open question, recommended for stores).
- **Threats considered:** stalking/coercive control (mitigated by transparency + notifications + easy exit), code brute force, IDOR via rules gaps (rules tests), stale data leakage after removal, leaked API keys.
- **Legal (needs counsel):** privacy policy, terms, store disclosures, GDPR/CCPA rights, minors. No legal text is generated in this baseline.
