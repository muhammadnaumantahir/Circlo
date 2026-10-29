# Security & Privacy (DRAFT v0.3 — Firebase-only)

## Principles
Consent-based, transparent, revocable, least data, default deny. Extra care because **minors may use the app**.

## Controls
- **Authentication:** Firebase Authentication manages user identity; Firestore Security Rules use the authenticated Firebase UID for every protected read/write. Anonymous access is denied.
- **Authorization:** Firestore Security Rules with default-deny behavior; membership and `sharesLocation` / `paused` must be checked for the exact circle. Live-location list queries are restricted to `sharing == true`, location writes require active consent, and pausing/stopping/removal must delete the projection in the same atomic batch. Parent-circle existence is required for membership-scoped access so orphaned subcollection data becomes unreadable. Emulator rule tests are mandatory. Never rely only on client-side checks.
- **Join codes:** ≥8 chars from an unambiguous alphabet, unguessable and revocable. Because trusted server-side rate limiting and privileged join flows are not available under Spark/no billing, these flows must be proven safe with Firestore Rules or deferred; never expose a public listing of valid codes.
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

## Automatic Place Suggestions

Place Suggestions are a separate opt-in from Travel History. They remain off unless both `keepHistory` and `placeSuggestionsEnabled` are true. The app reads only the signed-in user's private history documents inside the configured retention window; it never reads another member's circle-shared history to build suggestions. Candidate clustering runs in memory on the device and is not written to Firestore. A suggestion is not a circle place until the user opens the normal place editor, reviews the name/pin and explicitly saves it. Dismissing a suggestion hides it for the current Places view only; it does not delete travel history. Turning off Travel History automatically revokes Place Suggestions consent.

## Travel history (Increment 4)
Off by default at two levels: the user must switch on "Keep my travel history", then separately share it per circle (consent dialog). Circle copies are readable from Firestore only while the owner keeps the master “Keep my travel history” switch, per-circle history sharing, and location sharing on; rules block subsequent server reads and writes when any required switch is off. Turning the master switch off therefore protects existing server-side copies, but it cannot remotely erase data already cached on a recipient's device. The app removes copies best-effort. Only daily summaries (stops ≥10 min, thinned route) are stored — never raw GPS tracks or battery/device data. Retention (7/30/90 days) and deletion (range/all) are user-controlled; enforcement is client-side (see docs/risks.md).

## Threats considered
Stalking/coercive control (transparency + notifications + easy exit); join-code brute force; Firestore Rules gaps/IDOR (tests); forged place events from modified clients (remote alerts must remain disabled until trusted validation exists); leaked keys; stale data after removal; quota exhaustion (availability).

## Legal
Privacy policy, terms, and regional compliance (e.g. GDPR, COPPA) need review by a qualified professional; **no legal text is generated in this baseline** and nothing here is legal advice.
