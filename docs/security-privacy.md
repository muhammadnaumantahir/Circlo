# Security & Privacy (DRAFT v0.2)

## Principles
Consent-based, transparent, revocable, least data, default deny. Extra care because **minors may use the app**.

## Controls
- **Authentication:** Firebase Auth; backend verifies the ID token (JWT) on every request; no anonymous access.
- **Authorization:** Postgres RLS default-deny + RPC functions; membership and `shares_location` checked server-side; automated RLS tests in CI (NFR-006).
- **Join codes:** ≥8 chars from an unambiguous alphabet, server-side only, expiry/revocation, rate limit (NFR-011), uniform error messages.
- **Transparency:** consent screen, persistent sharing indicator (Android foreground notification / iOS indicator), "Who sees me", notification when added to a circle or when sharing is switched on/off. No stealth mode, no hidden icon.
- **Revocation:** leaving/removal deletes membership; RLS denies immediately.
- **Minimization:** no contacts, battery, analytics or ad SDKs. Birth year/age band only (for minor safeguards), not full date of birth.
- **Secrets:** FCM service account and Supabase service key only in provider/CI secrets; `.env.example` placeholders; secret scanning in CI. The Supabase **anon** key is public by design — safety comes from RLS.
- **Deletion/retention:** FR-006/066/067, NFR-012; `delete_account` removes DB rows, Storage files, tokens and the Firebase Auth user.
- **Abuse:** per-user rate limits, member/circle caps, report/block mechanism (open).

## Minors (owner decision: allowed — details need legal review before public launch)
- Proposed: minimum age **13** (higher in some regions, e.g. up to 16 in parts of the EU); under-13 accounts are **not supported in MVP** because verifiable parental consent isn't feasible at $0. *(Needs owner confirmation — see Q2.)*
- Age declared at sign-up; minors get plain-language consent text; minors can pause or leave at any time; guardian circle owners are notified when a minor pauses sharing or leaves (so safety use-cases work without hidden tracking).
- No hidden or forced tracking; no ads/analytics; minors' history sharing is off by default and only visible to circle members the minor shares with.
- Store policies (Google Play Families/Data safety, Apple privacy labels) must be reviewed before store release.

## Threats considered
Stalking/coercive control (transparency + notifications + easy exit); join-code brute force; RLS gaps/IDOR (tests); forged place events by a modified client (impact limited to that member's own events; server validates membership and rate-limits); leaked keys; stale data after removal; backend auto-pause or quota exhaustion (availability).

## Legal
Privacy policy, terms, and regional compliance (e.g. GDPR, COPPA) need review by a qualified professional; **no legal text is generated in this baseline** and nothing here is legal advice.
