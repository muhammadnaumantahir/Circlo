# Circlo — Project Brief

**Status:** Planning baseline DRAFT — awaiting owner approval (see [project-status.md](project-status.md)).

## What we are building
Circlo is a mobile app (Android + iOS) that lets families and friends share their live locations inside **private circles**, get **arrival/departure alerts** for saved places, and review each other's **travel history** — always with the sharing person's knowledge and consent.

## Problem and why it matters
Families and friend groups want to know "are you okay / are you home yet?" without repeated calls and texts. Existing apps do this, but location data is highly sensitive, so trust, transparency and user control are the product's core value, not an afterthought.

## Intended users
- **Parents / guardians** who want to know children have arrived at school or home.
- **Adult family members and friends** who want to coordinate and stay connected.
- **Members being shared** — they must always be able to see, pause, and revoke sharing.

## Value proposition
Private, consent-based location sharing with useful place alerts and history, and strong user control over who sees what.

## Core user journeys
1. Sign up → create a circle → share join code → members join.
2. Open map → see members, status, last update → tap for details/directions.
3. Save a place (e.g. school) → receive arrive/leave alerts for chosen members.
4. Pick a date → see a member's timeline (visits, stays, route), if they share history.
5. Pause sharing / leave circle / delete data / delete account.

## Platforms
Android and iOS via one Flutter codebase (recommended in the source requirements; see [architecture.md](architecture.md)).

## First release (MVP) goal
A reliable core: accounts, circles with join codes, live map with consent controls, saved places with arrival/departure alerts, and basic travel history with deletion/retention controls. Detailed scope: [requirements.md](requirements.md) §2 and §13.

## Success criteria (proposed — for approval)
- A new user can create a circle and a second user can join in under 3 minutes (usability test, 5 participants).
- Arrival/departure alert delivered within 2 minutes of the event for ≥90% of test visits in field testing.
- 0 unauthorized location reads in security-rule tests.
- Battery drain from Circlo background location ≤5% per day in standard test devices (target to be validated).

## Constraints known
- Budget/hosting: unknown; Google Maps, Firestore and Cloud Functions incur usage-based costs.
- Deadline: not stated.
- Platform rules for background location (Android foreground-service/permission rules, iOS "Always" permission and review) strongly shape the design.

## Confirmed vs assumed
See [requirements.md](requirements.md) §12 (Assumptions) and §13 (Open questions). Source of confirmed requirements: the owner's *Circlo — App Requirements Document*. Everything marked **[ASSUMPTION]** or **[RECOMMENDED]** is not yet confirmed.
