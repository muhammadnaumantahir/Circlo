# Test Plan (Increment 1)

Statuses: **Passed / Failed / Blocked / Not run / N/A**. Status below reflects what was actually executed when this file was last updated (2026-10-13, authoring environment without Flutter SDK or Firestore emulator access).

| Req | Check | Where | Command | Status |
|---|---|---|---|---|
| FR-001–003 | Sign-up/log-in/reset flows | manual with Firebase project/emulator | `flutter run` | Not run |
| FR-001, FR-002 | Login form validation | `app/test/login_screen_test.dart` | `flutter test` | Not run (CI) |
| FR-004, FR-102 | Validators: name, phone, email, password, birth year, min age 13 | `app/test/validators_test.dart` | `flutter test` | Not run (CI) |
| FR-011, NFR-011 | Join-code generation/format | `app/test/join_code_test.dart` | `flutter test` | Not run (CI) |
| FR-012 | Web invite code prefill and manual join-code entry | `app/test/circle_invite_test.dart` | `cd app && flutter test test/circle_invite_test.dart` | Added on 2026-10-28; Not run here |
| FR-012 | QR invite and OS share sheet on web, Android and iOS; expired code blocked from sharing/QR | manual web + native devices | manual | Not run — required |
| FR-004, FR-102, NFR-006 | Profile rules: own-only, age ≥13, immutable birth year | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); runs in CI |
| FR-010, FR-011 | Create circle batch rules | same | same | Blocked here; CI |
| FR-013, FR-020 | Join with valid/invalid/revoked/expired code; rotate code | same | same | Blocked here; CI |
| FR-017, FR-019, FR-090, FR-092 | Membership-scoped reads; leave/remove revokes access | same | same | Blocked here; CI |
| FR-030–035, FR-090 | Location rules: writes require active consent; list query requires `sharing == true`; direct get checks the marker and current per-circle consent; pausing/stopping/removal requires atomic location deletion; legacy/orphan documents are denied | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Added on 2026-10-28; Not run here |
| Privacy regression | A member cannot pause/stop sharing while leaving a location document behind; location data becomes unreadable when the parent circle is missing | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Added on 2026-10-28; Not run here |
| CI | Flutter analyze/unit tests plus Firestore Emulator rules tests | `.github/workflows/flutter_ci.yml` (manual dispatch) | GitHub Actions → Flutter CI → Run workflow | Updated on 2026-10-28; Not run here |
| FR-031, FR-032, NFR-016 | Status derivation, "ago" text, upload throttle, freshness validation for stale/future-dated fixes | `app/test/sharing_status_test.dart` | `flutter test` | Freshness tests added on 2026-10-28; Not run here |
| FR-033, FR-037, NFR-004 | Background sharing, notification/indicator, battery | real devices (docs/platform-setup.md) | manual | **Not run — required** |
| FR-036, FR-034, FR-035 | Consent dialog, pause, per-circle switches, permission states | manual with emulator/real device | manual | Not run |
| FR-005, FR-034–036 | Location permission state refreshes after changing device/app settings; retry permission-check errors | manual Android/iOS | Change permission or location services in system settings, return to Circlo, and verify the displayed state updates without a full app restart | Not run — required |
| FR-005 | Location Sharing screen retries when its circles query fails | manual web + native devices | Simulate offline state, open Location sharing, then reconnect and tap Retry | Not run — required |
| FR-040–051, FR-090 | Place/subscription/event rules: member-only reads, creator/owner edits, own-only subscriptions, forged/duplicate/paused/not-sharing events rejected, immutable events | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); CI |
| FR-048, FR-050 | Detector: arrival/departure confirmation, boundary jitter, one event per visit, restore after restart, inaccurate fixes | `app/test/place_detector_test.dart` | `flutter test` | Not run (CI) |
| Regression | Latest departure restores the detector to outside state; reactivated tracking must not emit a duplicate departure for the old visit | `app/test/place_detector_test.dart` | `cd app && flutter test test/place_detector_test.dart` | Added on 2026-10-28; Not run here |
| FR-040 | Geocoder parsing, short-query guard | `app/test/geocoder_test.dart` | `flutter test` | Not run (CI) |
| FR-045/046/047/044 | End-to-end alert flow (two devices, real GPS movement), in-app feed filtering by member/arrive/leave | manual, 2 devices + emulator | manual | **Not run — required** |
| FR-060–067, FR-090, FR-092 | History rules: master copy owner-only & requires keepHistory; circle copy requires sharing on/not paused/historyShared; member-only single reads; revoke and sharing-off hide it; batch-safe deletes; removed members lose access; separate opt-in | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); CI |
| FR-061, FR-062, FR-064, FR-068 | Track builder: visits ≥10 min, named vs Unknown place, home→university→home timeline, route thinning/cap, day rollover, restore, clock/duration formatting | `app/test/track_builder_test.dart` | `flutter test` | Not run (CI) |
| FR-060–067, FR-090 | Master history switch off hides existing circle copies and blocks new/updated copies even when per-circle sharing remains on | `firebase/tests/rules.test.mjs` — travel history | `cd firebase && npm test` | Added on 2026-10-28; Not run here |
| FR-065, FR-066, FR-067 | History UI: settings, per-circle sharing, retention, delete range/all, "not shared" states | manual (emulator + 2 users) | manual | **Not run — required** |
| FR-007, FR-014, FR-018, FR-020, FR-022, FR-090 | Lifecycle rules: verified email required; join-code expiry bounds; approval toggle; request → approve → join; no self-approval; only owner lists requests; ownership transfer needs one batch with role flips; circle deletion batch; owner cannot simply leave; profile delete | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); CI |
| Models | Circle/Member/JoinRequest parsing, alert filtering | `app/test/models_test.dart` | `flutter test` | Not run (CI) |
| FR-006, FR-007, FR-014, FR-018 | Account deletion end-to-end, email verification with the Auth emulator, approval/transfer/delete UI | manual (emulator + 2 users) | manual | **Not run — required** |
| FR-080, FR-081, FR-082, FR-083, FR-094, FR-038 | Rules: activity events bound to the actor's own batch (joined/left/removed/sharing), names must match, immutable, member-only reads; notification prefs bounds; timed pause field | `firebase/tests/rules.test.mjs` | `cd firebase && npm test` | Blocked here (emulator download blocked); CI |
| FR-072, FR-093 | Directions URL (no key), data export content | `app/test/directions_export_test.dart` | `flutter test` | Not run (CI) |
| FR-080–083 | Feed: kinds, mute, unread badge, unavailable notice after 15 min, join-request notice (owner) | manual (emulator + 2 users) | manual | **Not run — required** |
| Static | `flutter analyze`, `flutter test` | `.github/workflows/flutter_ci.yml` (manual `workflow_dispatch`) | CI job `verify` | Not run here |
| Security | Secret scan | CI | gitleaks | Not run |

Not verified yet: full end-to-end location sharing, places/history/notification workflows across two devices, account deletion, accessibility audit, and real-device background tracking. Automated coverage exists for several core flows but has not been run in this authoring environment.
