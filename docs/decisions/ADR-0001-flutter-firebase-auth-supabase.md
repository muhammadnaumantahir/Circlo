# ADR-0001: Flutter + Firebase Auth (login only) + free-tier Supabase backend
**Status:** Proposed (revised 2026-10-12; replaces "Flutter + Firebase everything")
**Context:** Owner budget is $0; app must target web, Android, iOS; Firebase to be used only for login. Cloud Functions are not on the free Spark plan and Cloud Storage requires Blaze (verify in console), so Firebase-only cannot send push or run server logic for free.
**Options:** (A) Flutter + Firebase Auth + Supabase free; (B) Flutter + Firestore on Spark, no server code (no push sending, no cleanup jobs); (C) Flutter + Supabase Auth only (drop Firebase login); (D) Firebase on Blaze with budget cap (needs billing account).
**Decision:** A. FCM remains for push (free) and requires a Firebase project anyway.
**Consequences:** Two providers to configure; Supabase must accept Firebase JWTs (spike to confirm; fallback is C, which is simpler and is recommended if the integration is awkward); free-tier caps and auto-pause shape the design (architecture §9).
