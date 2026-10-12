# Screen Specification (DRAFT)

Global states for every data screen: **Loading** (skeleton), **Empty** (illustration + CTA), **Error** (message + Retry), **Offline** (banner, show cached), **Permission-denied** (explain + "Open settings"). Requirement IDs refer to [requirements.md](../requirements.md).

## S1 Welcome / Login / Sign up / Reset password (FR-001–003, FR-007)
- Purpose: authenticate. Components: logo, email, password (show/hide), primary button, "Forgot password", switch login/sign-up, terms/privacy links.
- Validation: email format; password ≥8; inline errors. Errors: "Incorrect email or password" (no account enumeration), network error, too-many-attempts.
- Success: reset → "If an account exists, we sent a link". After sign-up → profile setup (name, photo, phone optional) then consent intro.

## S2 Onboarding & consent (FR-036, FR-005)
- Explains what is shared (location), with whom (selected circles), how to pause. Requests location "While using" then "Always" with rationale screen, notification permission. Skippable; app works without sharing (can view others only if they share).

## S3 Main Map (FR-030–035, 070–074)
- Components: map, member avatar markers with status ring, saved-place circles, circle switcher (top), "Pause sharing" toggle/status chip (always visible), member list toggle (accessible alternative), recenter button.
- Tap member → bottom sheet: name, photo, status, last updated, address/coords, "Directions", "View history" (if allowed).
- States: no members sharing (empty), location off (banner with CTA), stale data (grey marker + time).

## S4 My Circles (FR-010–021, 091)
- List of circles with member count; "Create" and "Join with code" actions.
- Circle detail: members + roles, join code (show/copy/share/revoke/expiry), approval toggle, pending requests, "Share my location with this circle" toggle, leave, (owner) transfer/delete.
- Validation: name 1–40; code input 8 chars. Errors: invalid/expired code, circle full, already member.

## S5 Saved Places (FR-040–051)
- List with name, radius, alert on/off. Add flow: search → pin on map → name → radius slider → members to monitor → alerts toggles (arrive/leave) → save. Edit/delete with confirmation. Limit reached message.

## S6 Travel History (FR-060–068)
- Member picker + date picker; map with route polyline and visit pins; timeline list (Left/Arrived/Stay duration). States: "History not shared", "No data for this day", "Insufficient data for route".
- Controls (own history): share toggle, retention, delete by range.

## S7 Notifications (FR-080–083)
- Grouped by day; read/unread; tap deep-links (arrival → map/history). Empty: "No notifications yet".

## S8 Profile & Settings (FR-004–006, 034–035, 065–067, 081, 093)
- Profile edit; location permission status; sharing per circle; history sharing + retention + delete; notification toggles per type; "Who can see me"; change password; export data (Could); delete account (type-to-confirm; handles owned circles).

## Navigation
Bottom nav: Map · Circles · Places · History · Profile; Notifications via bell icon on Map app bar. Deep links from push notifications.
