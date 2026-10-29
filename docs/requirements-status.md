# Requirements status (2026-10-14)

Legend: **Written** = code exists in the repo but has **never been compiled or run** (no Flutter SDK or Firestore emulator in the authoring environment; CI has not run yet). **Partial** = some of the requirement is built. **Not built** = cannot or will not be built under the owner's constraints ($0, no billing, no trusted server). Nothing here is "Passed"; see [test-plan.md](test-plan.md).

| ID | Status | Notes |
|---|---|---|
| FR-001–003 | Written | Email/password sign-up, log-in/out, reset |
| FR-004 | Partial | Name and phone done; **profile picture not built** (Cloud Storage needs billing; initials shown) |
| FR-005 | Written | Permission status + shortcut to OS settings on the Location sharing screen |
| FR-006 | Written (best-effort) | Client-side deletion with re-authentication; cannot guarantee completeness (see risks) |
| FR-007 | Written | Verify-email gate in the app and in the rules |
| FR-010 | Partial | Name done; **circle picture not built** |
| FR-011, 013, 015–017, 019 | Written | Codes, join, multiple circles, member list, remove, leave |
| FR-012 | Written | Copy to clipboard, OS share sheet, on-device QR invites, and web invite links that prefill the join code. The web link preserves its destination through sign-in/profile setup. |
| FR-014 | Written | Approval toggle, requests, approve/reject, join completes when the requester's app opens |
| FR-018, 022 | Written | Transfer ownership, delete circle, owner blockers for account deletion |
| FR-020 | Written | Revoke/new code, optional expiry (24 h / 7 days) |
| FR-021 | **Not built** | Rules cannot count members without a trusted counter |
| FR-030–032, 034–037 | Written | Map, status, last update, pause, per-circle opt-in, consent dialog, persistent indicator (background behaviour unverified); member photos shown as initials |
| FR-033 | Written, unverified | Background updates via foreground service / iOS background mode; **needs real-device tests** |
| FR-038 | Written | Timed pause; resumes automatically only while the app is open |
| FR-040–044, 047, 049, 051 | Written | Search on submit (free geocoder) or tap-to-pin, radius 100–1000 m, edit/delete, per-place alert settings; 20-place limit is client-side only |
| FR-045, 046 | Partial | Detection and **in-app** notifications only; no phone push (deferred by owner) |
| FR-048 | Written | Hysteresis + per-visit de-duplication (device-side, rules block duplicates) |
| FR-050 | Partial | Only members sharing with the circle trigger alerts; no per-member notice that an alert applies to them |
| FR-060–068 | Written | History (opt-in), route + timeline, per-circle sharing, retention 7/30/90 days (client-side), delete range/all, "Unknown place" for unnamed stops |
| FR-070, 071, 073, 074 | Written | Map, member details, places on map, circle switcher |
| FR-072 | Written | Opens the maps app/browser with directions |
| FR-080 | Partial | Joined, left/removed, sharing started/stopped, arrivals/departures, join requests, unavailable: **in-app only** |
| FR-081, 082 | Written | Settings per kind and per circle; unread badge; 30-day window (documents are not auto-deleted) |
| FR-083 | Written | Derived on the viewer's device (15+ min, once per outage) while the app is open |
| FR-084 | **Not built** | Push permission/flow needs a paid server |
| FR-090–092 | Written | Rules enforce circle-scoped access; "visible to N members"; revocation |
| FR-093 | Written | JSON shown/copy-to-clipboard (not a file download) |
| FR-094 | Partial | Others are notified in-app when someone joins or starts sharing; no notice to the user themselves |
| FR-100, 101 | Written | One Flutter codebase; web shares only while the tab is open. Platform folders are generated with `flutter create` |
| FR-102, 103 | Written/Partial | Age gate (13+); simple consent text and history off by default; no extra minor-specific wording |
| FR-104 | **Not built** | The app does not know who is a minor (only the user's own birth year is stored privately) |
| FR-105 | Written | Device-side detection with server-side de-duplication |
| FR-112 | Written, local-only suggestion | Suggests repeated completed unknown stops from up to 14 days of the user's private Travel History; filters places already covered in the selected circle; the map pin and name must be reviewed; alerts start off. Requires history opt-in; no paid geocoder/backend. |
| NFR-001–004, 007 | Unverified | Targets need real devices; throttling is implemented |
| NFR-005, 006 | Written | Managed TLS/encryption; rules + emulator tests (not yet run) |
| NFR-008 | Partial | Text+icon statuses, semantic labels, list alternative to the map; no audit done |
| NFR-009 | Partial | Firestore offline cache gives last known data; no explicit upload queue |
| NFR-010 | Partial | English only; strings are inline, not externalised |
| NFR-011 | Partial | 49-bit join codes, never listable; **no rate limiting** possible without a server |
| NFR-012 | Partial | Best-effort client-side deletion; no automatic cleanup |
| NFR-013 | **Not built** | No crash reporting added |
| NFR-014 | **Not done** | Privacy policy, store disclosures and legal review are the owner's task |
| NFR-015, 016 | Written | $0 design: no Cloud Functions/Storage/billing; throttled writes; usage still needs watching |
