# Repository Review — 2026-10-13 (Firebase-only revision)

**Scope:** Static review of planning documentation. The repository contains no application code, so no build or runtime tests have been performed.

## Owner's updated decision

Circlo uses Flutter + Firebase Authentication + Cloud Firestore + Firebase Cloud Messaging, with no Supabase and no billing account. Native Android/iOS should attempt Life360-style background location, including while the screen is locked, subject to OS/OEM restrictions and permission grants. Web can share location only while the tab is open.

## P0 — Trusted server-side push and privileged operations are unresolved

Firebase Authentication, FCM delivery, and Cloud Firestore have no-cost usage options. However, Cloud Functions require the Blaze plan. Under the strict Spark/no-billing constraint, this baseline has no approved trusted backend to validate sensitive operations, send cross-user FCM messages, run scheduled cleanup, or perform complete account deletion.

Do not embed FCM server credentials in the client, disable security rules, or trust client-side authorization for privileged actions. Before claiming Life360-style remote arrival/departure alerts work, either prove a secure zero-cost server mechanism and obtain owner approval, or defer cross-user push and server-dependent features. Local notifications can only safely cover device-local events; they do not notify other circle members.

Official reference: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans

## P1 — Prove circle-scoped Firestore Rules

Rules must verify current membership and the exact owner's sharing permission for the specific circle—not merely that viewer and owner share any circle. Apply this to live locations, history, visits, saved places, place events, notifications, and realtime listeners.

Required Emulator tests:
- Circle A cannot read location/history shared only with Circle B.
- Pausing/revoking sharing denies future reads and writes as specified.
- Leaving/removal immediately denies further access.
- Unauthenticated users and accounts from another Firebase project are denied.
- A user cannot add themselves as a member, promote themselves, or approve their own request.
- Rules deny writes to another user's live location/history and prevent owner/role spoofing.

## P1 — Prove safe join codes and privileged mutations

Join codes, ownership transfers, member removal, account deletion and circle deletion are security-sensitive. Firestore rules alone may not safely implement every atomic/privileged flow. Prototype each required transaction in the Emulator; defer flows that cannot be secured without trusted server support. Rate limiting against join-code brute force also needs a trustworthy enforcement point.

## P1 — Background tracking is a product requirement, not a guarantee

Android should use a compliant foreground service and persistent notification when required. iOS requires appropriate location permissions and can still limit execution. OEM battery managers may terminate tracking. Web cannot track after its tab closes. Test on real Android devices (including aggressive battery-management OEMs) and real iPhones; do not claim reliability or battery targets until measured.

## P1 — Device-generated events are untrusted

The sharing device can generate arrival/departure events, reducing server work, but a modified client can forge them. Use stable event IDs and client-side debounce; do not send remote alerts based solely on untrusted event documents until a trusted validator exists. Document missed alerts when OS suspends/kills the app.

## P1 — Firestore quota and retention design

Firestore's free quota is limited and applies to the project. Frequent location writes and realtime listeners can exhaust reads/writes. Throttle uploads, keep the live location separate from history, cap history, and show clear sync-unavailable states. Do not assume Firestore TTL/managed deletes are available without billing; test explicit cleanup and account deletion. Avoid claiming complete deletion while no trusted recursive deletion mechanism exists.

Official reference: https://firebase.google.com/docs/firestore/quotas

## P1 — Map provider compliance

OpenStreetMap data is open, but public tile servers and public geocoders are not unlimited production APIs. Keep the provider configurable, show attribution, honor caching and identification rules, avoid bulk/offline tile downloads, and follow the chosen geocoder's policy.

Official reference: https://operations.osmfoundation.org/policies/tiles/

## P2 — Privacy, minors and distribution

Confirm minimum age and launch markets, and get appropriate legal/privacy review before launch. Retention must cover raw points, derived visits, notification records, tokens, and circle-owned data. iOS/Play distribution fees remain outside the $0 budget.

## Suggested next steps

1. Prototype Firestore Rules in the Firebase Emulator before storing real locations.
2. Resolve the no-billing trusted-server blocker or explicitly reduce MVP scope.
3. Test background location on real Android/iOS devices with the screen locked.
4. Validate map/geocoder terms and Firestore free quotas.
5. Only then implement the smallest vertical slice: sign-in → profile → secure create/join circle.

## Official references checked

- Firebase pricing plans: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- Firestore quotas: https://firebase.google.com/docs/firestore/quotas
- OpenStreetMap tile usage policy: https://operations.osmfoundation.org/policies/tiles/
