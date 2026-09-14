# M14 - Support Snapshot Strict Next-Step Validation

Status: Complete after M13 support next-step snapshot on 2026-09-14.

Goal: make support snapshot triage reject invalid next-step action codes without requiring real-device validation.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Do not change app runtime sync behavior in this slice.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M14.1 Inspector Validation

- [x] Reject missing or empty `nextStep`.
- [x] Reject Android snapshots with iOS-only next-step codes.
- [x] Reject iOS snapshots with Android-only next-step codes.

### M14.2 Documentation

- [x] Document strict support snapshot next-step validation.
- [x] Keep README and quickstart milestone index current.

### M14.3 Automated Gate

- [x] Keep support snapshot fixtures valid.
- [x] Keep inspector positive and negative validation checks passing.
- [x] Keep platform build/test and beta preflight gates green.

## Progress Log

### 2026-09-14 M14 Started

Tightened support snapshot next-step triage:

- The inspector now validates platform-specific next-step action codes.
- Android and iOS snapshot summaries continue to print the next-step action code for beta support.
