# Data Model (DRAFT)

Firestore collections (all docs include `createdAt`, `updatedAt` where relevant).

| Path | Key fields | Notes |
|---|---|---|
| `users/{uid}` | displayName, photoUrl, phone?, settings{historyShared, retentionDays, notifTypes{}}, fcmTokens[], sharingPaused | Readable by self; limited public profile fields (name, photo) readable by users sharing a circle |
| `circles/{cid}` | name, photoUrl?, ownerUid, requiresApproval, memberCount, activeCodeId | |
| `circles/{cid}/members/{uid}` | role (owner/member), joinedAt, sharesLocation (bool) | Presence = membership; used by rules |
| `circles/{cid}/requests/{uid}` | requestedAt, status | If approval enabled |
| `circles/{cid}/places/{pid}` | name, lat, lon, radiusM, createdBy, alerts{memberUid:{arrive,leave}} per subscriber | |
| `joinCodes/{code}` | circleId, createdBy, expiresAt?, revoked | Only Functions read/write |
| `liveLocations/{uid}` | lat, lon, accuracy, ts, status, sharedWith[cid] | Latest only; readable by members of a circle in `sharedWith` |
| `locationHistory/{uid}/points/{id}` | lat, lon, accuracy, ts, expireAt | Written by owner; read by circle members only if `historyShared` and circle in sharedWith; TTL on `expireAt` |
| `visits/{uid}/days/{yyyymmdd}/items/{id}` | placeId?, name?, lat, lon, arrivedAt, leftAt, durationSec | Built by function from points |
| `placeState/{cid}_{pid}_{uid}` | state, enteredAt, lastEventId | Function-only |
| `notifications/{uid}/items/{id}` | type, circleId, payload, createdAt, read | Retained 30 days |

Composite indexes: points by `(uid, ts)`; visits by `(uid, arrivedAt)`.
Migration approach: schema version field per doc type; scripted migrations via Functions, run in staging first.
