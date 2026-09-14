# M9 - Support Snapshot

Status: Complete after M8 beta preflight completion on 2026-09-14.

Goal: standardize copied diagnostics into a redacted JSON support snapshot for internal beta reports.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Support snapshots must not include pairing tokens, request signatures, shared secrets, private signing material, media bytes, Apple ID data, iCloud credentials, or iCloud Drive data.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M9.1 Shared Snapshot Contract

- [x] Add shared support snapshot JSON schema.
- [x] Add Android and iOS sample support snapshot fixtures.
- [x] Validate support snapshot fixtures in the existing fixture gate.

### M9.2 Platform Diagnostics Output

- [x] Convert Android copied diagnostics to support snapshot JSON.
- [x] Convert iOS copied diagnostics to support snapshot JSON.
- [x] Preserve explicit redaction markers for excluded secrets.

### M9.3 Documentation

- [x] Document support snapshot fields.
- [x] Document redaction rules.
- [x] Document platform-specific snapshot contents.

### M9.4 Automated Gate

- [x] Keep fixture validation, Swift tests, Android compile/tests, iOS build, repo hygiene, and beta preflight green.

## Progress Log

### 2026-09-14 M9 Started

Started support snapshot standardization:

- Added `shared/schemas/support-snapshot.schema.json`.
- Added Android and iOS support snapshot fixtures.
- Added fixture validation for support snapshots.
- Updated Android and iOS copied diagnostics to output redacted JSON support snapshots.

### 2026-09-14 M9 Automated Gate Passed

Completed the M9 automated gate:

- `python3 scripts/validate-fixtures.py` passed.
- `swift test` passed.
- `./gradlew :app:testDebugUnitTest :app:compileDebugKotlin` passed.
- `xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -destination generic/platform=iOS build` passed.
- `bash scripts/check-beta-preflight.sh --transport signed-http --full` passed.
