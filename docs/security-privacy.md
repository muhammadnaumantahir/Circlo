# Security & Privacy (DRAFT v0.3 — Firebase-only)

## Principles
Consent-based, transparent, revocable, least data, default deny. Extra care because **minors may use the app**.

## Controls
- **Authentication:** Firebase Auth; backend verifies the ID token (JWT) on every request; no anonymous access.
- **Authorization:** Firestore Security Rules with default-deny behavior; membership and `shares_location` must be checked for the exact circle. Emulator rule tests are mandatory. Never rely only on client-side checks.
- **Join codes:** ≥8 chars from an unambiguous alphabet, server-side only, expiry/revocation, rate limit (NFR-011), uniform error messages.
- **Transparency:** consent screen, persistent sharing indicator (Android foreground notification / iOS indicator), "Who sees me", notification when added to a circle or when sharing is switched on/off. No stealth mode, no hidden icon.
- **Revocation:** leaving/removal deletes membership; Firestore Rules denies immediately.
- **Minimization:** no contacts, battery, analytics or ad SDKs. Birth year/age band only (for minor safeguards), not full date of birth.
- **Secrets:** Never ship FCM service-account credentials or other server secrets in the Flutter app. FCM delivery is free, but a trusted sender is required; Cloud Functions need Blaze, so cross-user remote push remains blocked until a secure no-cost server path is approved.
- **Deletion/retention:** FR-006/066/067, NFR-012; account deletion must remove Firestore documents/subcollections, tokens, and Firebase Auth identity. Without a trusted backend, complete recursive deletion and scheduled retention cleanup are not yet guaranteed; do not claim full deletion until tested.
- **Abuse:** per-user rate limits, member/circle caps, report/block mechanism (open).

## Minors (owner decision: allowed — details need legal review before public launch)
- Proposed: minimum age **13** (higher in some regions, e.g. up to 16 in parts of the EU); under-13 accounts are **not supported in MVP** because verifiable parental consent isn't feasible at $0. *(Needs owner confirmation — see Q2.)*
- Age declared at sign-up; minors get plain-language consent text; minors can pause or leave at any time; guardian circle owners are notified when a minor pauses sharing or leaves (so safety use-cases work without hidden tracking).
- No hidden or forced tracking; no ads/analytics; minors' history sharing is off by default and only visible to circle members the minor shares with.
- Store policies (Google Play Families/Data safety, Apple privacy labels) must be reviewed before store release.

## Threats considered
Stalking/coercive control (transparency + notifications + easy exit); join-code brute force; Firestore Rules gaps/IDOR (tests); forged place events by a modified client (impact limited to that member's own events; server validates membership and rate-limits); leaked keys; stale data after removal; backend auto-pause or quota exhaustion (availability).

## Legal
Privacy policy, terms, and regional compliance (e.g. GDPR, COPPA) need review by a qualified professional; **no legal text is generated in this baseline** and nothing here is legal advice.
