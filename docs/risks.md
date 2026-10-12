# Risk Register (DRAFT)

| ID | Risk | Impact | Mitigation | Decision needed |
|---|---|---|---|---|
| R-01 | Background location killed by OS/OEM battery managers | High: core feature unreliable | Early spike (ADR-0003), foreground service, user guidance, device matrix | Plugin choice/licence |
| R-02 | iOS/Google Play rejection for background location | High | Clear in-app disclosure, justification text, privacy labels | — |
| R-03 | Privacy misuse (stalking/coercion) | High | Transparency features, notifications on sharing, easy exit, abuse reporting | Block/report feature scope |
| R-04 | Cloud cost growth (Maps, Firestore writes, Functions) | Medium–High | Adaptive sampling, cost model, budget alerts, quotas | Monthly budget (Q4) |
| R-05 | Duplicate/missed place alerts (GPS jitter) | Medium | Hysteresis + debounce + idempotent dedup, simulated-track tests | — |
| R-06 | Minors / legal compliance (COPPA/GDPR-K) | High | Legal advice, age gate | Q2, Q3 |
| R-07 | Security-rule gaps expose locations | High | Default deny, emulator rule tests in CI | — |
| R-08 | Battery drain bad reviews | Medium | Targets NFR-004, tuning | — |
| R-09 | Apple Developer account/Mac required for iOS | Medium | Plan CI builds (Codemagic/GitHub macOS) | Q1 |
| R-10 | Versions/quotas/policies outdated in this plan | Medium | Verify with official docs before implementation | — |
| R-11 | Firestore limits for history queries | Medium | Revisit ADR-0001 if needed | — |
