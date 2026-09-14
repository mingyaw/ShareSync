# M13 - Support Next-Step Snapshot

Status: Complete after M12 readiness presenter hardening on 2026-09-14.

Goal: include the tested next-step state in copied support snapshots so internal beta triage can identify the user's next action without reading localized UI text.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Do not include pairing tokens, request signatures, shared secrets, media bytes, or credentials in support snapshots.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M13.1 Snapshot Contract

- [x] Add required `nextStep` field to the support snapshot schema.
- [x] Keep `nextStep` machine-readable and non-localized.
- [x] Update support snapshot fixtures.

### M13.2 Platform Snapshot Output

- [x] Add Android support snapshot next-step output.
- [x] Add iOS support snapshot next-step output.
- [x] Derive both from the tested readiness presenter state.

### M13.3 Triage Tooling

- [x] Update fixture validation to require `nextStep`.
- [x] Update the support snapshot inspector to validate and summarize `nextStep`.
- [x] Keep beta preflight and platform checks green.

## Progress Log

### 2026-09-14 M13 Started

Added next-step data to support snapshots:

- Android diagnostics now include a stable next-step action code.
- iOS diagnostics now include a stable next-step action code.
- Schema, fixtures, fixture validation, inspector summaries, M9 docs, and M10 docs were updated to include `nextStep`.
