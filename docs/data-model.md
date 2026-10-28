# Data Model (DRAFT v0.3 — Firebase Cloud Firestore)

Firebase Authentication UID is the stable user key. Use Firestore documents and subcollections; all access is governed by firestore.rules with default-deny behavior. This is a logical model, not deployed code.

| Collection / path | Example fields | Access rule (summary) |
|---|---|---|
| users/{uid} | display_name, photo_url?, phone?, birth_year/age_band, history_shared=false, retention_days=30, sharing_paused=false, created_at | User reads/writes own private fields; only minimal profile fields shared to current circles |
| users/{uid}/deviceTokens/{tokenId} | token, platform, updated_at | Owner only; tokens never exposed to other members |
| circles/{circleId} | name, photo_url?, owner_uid, requires_approval, member_count, created_at | Current members read; sensitive changes require validated rules and, where needed, trusted server support |
| circles/{circleId}/members/{uid} | role, joined_at, shares_location, history_shared | Current members can read membership; a member may change only their own allowed sharing preferences |
| joinCodes/{codeId} | circle_id, expires_at?, revoked, created_by | No public listing; joining must not trust a client-supplied circle ID. A safe one-time/transactional join flow must be proven in Rules or deferred until trusted server support exists |
| joinRequests/{requestId} | circle_id, uid, status, created_at | Requester and circle owner only |
| circles/{circleId}/places/{placeId} | name, lat, lon, radius_m, created_by, alerts_enabled | Current circle members read; writes limited to authorized owners/creators |
| circles/{circleId}/placeSubscriptions/{subscriptionId} | subscriber_uid, member_uid, on_arrive, on_leave | Subscriber controls own subscription; server-side authorization needed before sending remote alerts |
| users/{uid}/live/current | lat, lon, accuracy, recorded_at, status | Owner writes; circle members read only if current membership and per-circle sharing permission both allow it |
| users/{uid}/locationHistory/{pointId} | lat, lon, accuracy, recorded_at | Owner writes/reads; other members read only with history opt-in and current circle-scoped sharing authorization |
| users/{uid}/visits/{visitId} | place_id?, name?, lat, lon, arrived_at, left_at, duration_s | Same access as history; owner can delete |
| placeEvents/{eventId} | circle_id, place_id, member_uid, type, visit_id, occurred_at, idempotency_key | Treat client-created events as untrusted; validate membership/subscription/timestamp/rate server-side before sending remote alerts |
| users/{uid}/notifications/{notificationId} | type, circle_id, payload, read, created_at | Recipient only; remote creation needs trusted sender. Local notifications may be generated on-device for that device only |

## Implemented in Increment 1 (see `firebase/firestore.rules`)
`users/{uid}` (displayName, phone?, birthYear, createdAt, updatedAt) · `circles/{id}` (name, ownerUid, requiresApproval=false, joinCode, createdAt) · `circles/{id}/members/{uid}` (uid, role, displayName, joinedAt, joinCode for members) · `joinCodes/{code}` (circleId, createdBy, revoked, createdAt, expiresAt?).
**Increment 2 additions:** `circles/{id}/members/{uid}` gains `sharesLocation` (bool, default false) and `paused` (bool, default false); `circles/{id}/locations/{uid}` stores `uid`, `lat`, `lng`, `accuracy`, `sharing=true`, and `updatedAt=server time`. It is a **circle-scoped projection** written only while sharing is enabled and not paused for that exact circle. List queries must filter `sharing == true`; direct reads check the owner's current sharing consent. Rules require location deletion in the same atomic batch when sharing is switched off/paused or membership is removed, and parent-circle existence gates all circle membership reads so orphaned child data is not exposed after circle deletion. The same position is written once per active circle (cost: N writes per update).
**Increment 3 additions (circle-scoped):** `circles/{id}/places/{placeId}` (name, lat, lng, radiusM 100–1000, createdBy, createdAt; creator or circle owner edits/deletes; max 20 per circle enforced in the app only) · `circles/{id}/placeSubscriptions/{uid_placeId}` (subscriberUid, placeId, arrive, leave, allMembers, memberUids ≤20, optional `paused` bool defaulting to false for legacy documents, updatedAt; private to the subscriber; replaces the per-member subscription shape above) · `circles/{id}/placeEvents/{memberUid_placeId_visitId_type}` (placeId, placeName, memberUid, memberName, type arrive|leave, visitId, occurredAt=server time; immutable; created only by the member themself while sharing is on and not paused; name fields must match the place/member documents; the id gives idempotency; **untrusted, in-app feed only**). Events live under the circle (not top-level) so authorization stays circle-scoped; there is no `idempotency_key` field because the document id is the key.
**Increment 4 additions (history):** history is stored as **one compact document per member per local day**, not raw GPS points (free-tier writes): `users/{uid}/history/{yyyymmdd}` = private master copy (uid, day, tzOffsetMin, visits[≤60] {placeId?, name, lat, lng, arrivedAt, leftAt|null}, route[≤400] {lat,lng,t} thinned to ≥50 m steps, lastSeen, updatedAt); `circles/{id}/history/{uid_yyyymmdd}` = circle-scoped copy, written only while sharing is on, not paused **and** `historyShared` is on for that circle, readable by members only while the owner keeps `historyShared` and `sharesLocation` on (single-document reads, no list). New fields: `users.keepHistory` (default false), `users.retentionDays` (7/30/90, default 30), `circles/{id}/members/{uid}.historyShared` (default false, always starts off). Stops ≥10 min become visits (named when inside a saved place, else "Unknown place"). Retention is enforced by the client (see risks); there are no TTLs. Deviations from the earlier logical model: `locationHistory` raw points and top-level `visits` are replaced by the daily documents above.
Deviations from the logical model above: `member_count` is derived on the client (no trusted counter); member docs carry a denormalized `displayName` and a `uid` field so users can find their circles with a collection-group query. Approval requests, ownership transfer/deletion and location-related collections are implemented in source; see `CHANGELOG.md`, `project-status.md`, and the current feature audit. Account/circle deletion and retention remain best-effort under the no-server constraint.

## Query and security rules

- Use circle-scoped paths for shared data; do not rely on matching membership in any circle.
- Every read must verify current membership and the exact owner's shares_location permission for that circle. History additionally requires history_shared.
- Leaving/removal must immediately deny future reads. Security rules cannot erase data already downloaded to a device.
- Clients must never write another user's location or profile, assign themselves owner, approve their own join request, or grant their own membership.
- A single live/current document per user is simple but makes cross-circle authorization subtle; if Firestore rules cannot safely prove the viewer-to-owner relationship for each circle, duplicate circle-scoped location projections or defer the query.
- Stable event IDs must be generated once and reused for retries; enforce idempotency in the trusted processing layer when available.
- Retention: keep live location separate from history. Prune history and notification documents using an explicitly tested cleanup process. Firestore TTL/managed deletes require billing, so no TTL-based deletion is assumed under Spark.
- Store only the data needed; do not collect battery, contacts, or background data unrelated to the feature.

## Free-tier and implementation notes

- Cloud Firestore has a no-cost daily quota (currently documented as 1 GiB stored, 50,000 document reads/day, 20,000 writes/day and 20,000 deletes/day; verify before launch). Exceeding Spark quota can disable that product until the quota resets.
- Do not store profile images in Firebase Storage unless its current Spark availability and cost are confirmed; use initials/avatar placeholders for MVP.
- Firestore Rules and Emulator Suite tests are mandatory before any live location data is used.
