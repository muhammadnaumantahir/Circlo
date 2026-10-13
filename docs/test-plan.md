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
| Static | `flutter analyze`, `flutter build web` | CI (not enabled yet: copy docs/ci/ci.yml to .github/workflows/) | CI job `flutter` | Not run |
| Security | Secret scan | CI | gitleaks | Not run |

Not covered yet (later increments): location sharing, places, history, notifications, account deletion, accessibility audit, real-device background tracking.
