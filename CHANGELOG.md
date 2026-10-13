# Changelog

## [Unreleased]
### Added
- Increment 1 (foundation): Flutter app skeleton (web/Android/iOS), email/password sign-up/log-in/log-out/password-reset with age gate (13+), profile setup and edit, create circle, join with code, member list, leave circle, owner removes members, owner rotates join code.
- Firestore Security Rules (default deny, circle-scoped) with emulator tests; GitHub Actions CI workflow (stored in docs/ci/ci.yml until enabled).
- Increment 2 (location sharing): Map tab (OpenStreetMap-based, flutter_map) with circle switcher and member list, per-circle opt-in sharing with consent dialog, pause-all, permission handling, status (Sharing / Paused / Location unavailable / Not sharing) with last-updated, throttled uploads + heartbeat, atomic stop/cleanup on pause, leave, removal and log-out; circle-scoped location rules + tests; platform setup script/doc.
### Not yet implemented
Places/alerts, history, push notifications (deferred by owner decision), approval flow, ownership transfer, circle/account deletion.
