# Data Model (DRAFT v0.2 — Postgres on free-tier Supabase)

`uid` = Firebase Auth user id (text) taken from the verified JWT. All tables have Row Level Security **enabled with default deny**.

| Table | Key columns | Access rule (summary) |
|---|---|---|
| `profiles` | uid PK, display_name, photo_path, phone?, birth_year/age_band, history_shared bool, retention_days (7/30/90, default 30), sharing_paused bool, created_at | Self read/write; name+photo readable by users sharing a circle |
| `device_tokens` | uid, token, platform | Self only |
| `circles` | id, name, photo_path?, owner_uid, requires_approval, created_at | Members read; writes via RPC |
| `circle_members` | circle_id, uid, role (owner/member), joined_at, shares_location bool | Members read their circle's rows; self may toggle own `shares_location`; others via RPC |
| `join_codes` | code PK, circle_id, expires_at?, revoked | RPC only (no direct access) |
| `join_requests` | circle_id, uid, status, created_at | Owner & requester |
| `places` | id, circle_id, name, lat, lon, radius_m, created_by | Circle members read; creator/owner write |
| `place_subscriptions` | place_id, subscriber_uid, member_uid, on_arrive, on_leave | Subscriber only |
| `live_locations` | uid PK, lat, lon, accuracy, recorded_at, status | Readable by members of circles where owner `shares_location` is true |
| `location_points` | id, uid, lat, lon, accuracy, recorded_at | Owner full; circle members only if `history_shared` and sharing to that circle |
| `visits` | id, uid, place_id?, name?, lat, lon, arrived_at, left_at, duration_s | Same as points |
| `place_events` | id, circle_id, place_id, member_uid, type (arrive/leave), visit_id, occurred_at; UNIQUE(member_uid, place_id, visit_id, type) | Insert by the member only; read by service role |
| `notifications` | id, uid, type, circle_id, payload jsonb, read, created_at | Self only; auto-deleted after 30 days |

Indexes: `location_points(uid, recorded_at)`, `visits(uid, arrived_at)`, `circle_members(uid)`, `places(circle_id)`.
Retention: scheduled cleanup deletes points older than each user's `retention_days` and notifications >30 days.
Migrations: versioned SQL files in `/supabase/migrations`, tested on a fresh local database and the dev project before prod.
