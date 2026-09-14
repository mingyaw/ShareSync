# M15 - Support Snapshot Inspector Tests

Status: Complete after M14 strict next-step validation on 2026-09-14.

Goal: add repeatable regression tests for support snapshot triage without requiring real-device validation.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Do not change app runtime sync behavior in this slice.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M15.1 Inspector Regression Script

- [x] Add a reusable support snapshot inspector test script.
- [x] Verify valid Android and iOS support snapshots pass.
- [x] Verify missing `nextStep` is rejected.
- [x] Verify cross-platform next-step action codes are rejected.
- [x] Verify sensitive marker leakage is rejected.

### M15.2 Gate Integration

- [x] Run support snapshot inspector tests from the M0 main-axis check.
- [x] Run support snapshot inspector tests from beta preflight.

### M15.3 Documentation

- [x] Document the new support snapshot inspector regression gate.
- [x] Keep README and quickstart milestone index current.

## Progress Log

### 2026-09-14 M15 Started

Added a repeatable inspector regression gate so beta support diagnostics validate both positive fixtures and common broken snapshot cases.
