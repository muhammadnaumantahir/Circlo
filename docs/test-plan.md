# Test Plan (Increment 1)

Statuses: **Passed / Failed / Blocked / Not run / N/A**. Status below reflects what was actually executed when this file was last updated (2026-10-13, authoring environment without Flutter SDK or Firestore emulator access).

| Req | Check | Where | Command | Status |
|---|---|---|---|---|
| FR-001–003 | Sign-up/log-in/reset flows | manual with Firebase project/emulator | `flutter run` | Not run |
| FR-001, FR-002 | Login form validation | `app/test/login_screen_test.dart` | `flutter test` | Not run (CI) |
| FR-004, FR-102 | Validators: name, phone, email, password, birth year, min age 13 | `app/test/validators_test.dart` | `flutter test` | Not run (CI) |
| FR-011, NFR-011 | Join-code generation/format | `app/test/join_code_test.dart` | `flutter test` | Not run (CI) |
| FR-004, FR-102, NFR-006 | Profile rules: own-only, age ≥13, immutable birth year | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); runs in CI |
| FR-010, FR-011 | Create circle batch rules | same | same | Blocked here; CI |
| FR-013, FR-020 | Join with valid/invalid/revoked/expired code; rotate code | same | same | Blocked here; CI |
| FR-017, FR-019, FR-090, FR-092 | Membership-scoped reads; leave/remove revokes access | same | same | Blocked here; CI |
| FR-030–035, FR-090 | Location rules: write only when sharing on & not paused for that circle; no cross-circle writes; member-only reads; stop-sharing batch removes data; removed member loses read | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); CI |
| FR-031, FR-032, NFR-016 | Status derivation, "ago" text, upload throttle | `app/test/sharing_status_test.dart` | `flutter test` | Not run (CI) |
| FR-033, FR-037, NFR-004 | Background sharing, notification/indicator, battery | real devices (docs/platform-setup.md) | manual | **Not run — required** |
| FR-036, FR-034, FR-035 | Consent dialog, pause, per-circle switches, permission states | manual with emulator/real device | manual | Not run |
| FR-040–051, FR-090 | Place/subscription/event rules: member-only reads, creator/owner edits, own-only subscriptions, forged/duplicate/paused/not-sharing events rejected, immutable events | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); CI |
| FR-048, FR-050 | Detector: arrival/departure confirmation, boundary jitter, one event per visit, restore after restart, inaccurate fixes | `app/test/place_detector_test.dart` | `flutter test` | Not run (CI) |
| FR-040 | Geocoder parsing, short-query guard | `app/test/geocoder_test.dart` | `flutter test` | Not run (CI) |
| FR-045/046/047/044 | End-to-end alert flow (two devices, real GPS movement), in-app feed filtering by member/arrive/leave | manual, 2 devices + emulator | manual | **Not run — required** |
| FR-060–067, FR-090, FR-092 | History rules: master copy owner-only & requires keepHistory; circle copy requires sharing on/not paused/historyShared; member-only single reads; revoke and sharing-off hide it; batch-safe deletes; removed members lose access; separate opt-in | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); CI |
| FR-061, FR-062, FR-064, FR-068 | Track builder: visits ≥10 min, named vs Unknown place, home→university→home timeline, route thinning/cap, day rollover, restore, clock/duration formatting | `app/test/track_builder_test.dart` | `flutter test` | Not run (CI) |
| FR-065, FR-066, FR-067 | History UI: settings, per-circle sharing, retention, delete range/all, "not shared" states | manual (emulator + 2 users) | manual | **Not run — required** |
| Static | `flutter analyze`, `flutter build web` | CI (not enabled yet: copy docs/ci/ci.yml to .github/workflows/) | CI job `flutter` | Not run |
| Security | Secret scan | CI | gitleaks | Not run |

Not covered yet (later increments): location sharing, places, history, notifications, account deletion, accessibility audit, real-device background tracking.
