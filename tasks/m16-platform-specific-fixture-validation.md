# M16 - Platform-Specific Fixture Validation

Status: Complete after M15 support snapshot inspector tests on 2026-09-14.

Goal: make fixture validation enforce platform-specific support snapshot `nextStep` action codes.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Do not change app runtime sync behavior in this slice.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M16.1 Fixture Validator

- [x] Add Android support snapshot next-step allowlist.
- [x] Add iOS support snapshot next-step allowlist.
- [x] Reject fixture next-step values that do not belong to the fixture platform.

### M16.2 Documentation

- [x] Document why schema validation stays shared while fixture validation is platform-aware.
- [x] Keep README and quickstart milestone index current.

### M16.3 Automated Gate

- [x] Keep fixture validation passing.
- [x] Keep support snapshot inspector regression tests passing.
- [x] Keep beta preflight passing without real-device validation.

## Progress Log

### 2026-09-14 M16 Started

Aligned fixture validation with support snapshot inspector platform rules so sample diagnostics cannot silently drift into cross-platform next-step values.
