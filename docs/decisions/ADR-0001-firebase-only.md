# ADR-0001: Firebase-only architecture under a strict $0 budget

**Status:** Selected by owner on 2026-10-13; trusted server-side automation remains unresolved.
**Context:** Circlo targets Flutter web, Android and iOS. The monthly budget is $0 and no billing account may be linked. The owner selected Firebase Authentication, Cloud Firestore and Firebase Cloud Messaging. Native mobile background location should continue when the screen is locked, subject to platform permissions and restrictions.
**Options considered:** (A) Firebase Authentication + Cloud Firestore + FCM on Spark; (B) Firebase with Cloud Functions on Blaze; (C) Firebase plus a separate hosted backend; (D) self-hosted backend.
**Decision:** A for identity, app data and push delivery. Supabase is removed from the architecture.
**Critical consequence:** Firebase Cloud Functions require the Blaze plan. FCM delivery is no-cost, but sending messages to other users requires a trusted sender. Under Spark/no-billing there is currently no approved trusted service for cross-user push, sensitive mutations, scheduled cleanup, rate limiting or complete recursive account deletion. Do not put FCM service-account credentials in the client or pretend client-side checks are server authorization.
**Required follow-up:** Prototype Firestore Security Rules and all circle-scoped access in the Emulator. Prove a secure no-cost trusted-server option with owner approval, or explicitly defer remote push and server-dependent operations. Do not start full implementation until this blocker is resolved or the MVP scope is formally reduced.
**Official reference:** https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
