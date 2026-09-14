# M10 - Support Triage

Status: Complete after M9 support snapshot completion on 2026-09-14.

Goal: make copied support snapshots actionable during internal beta support without requiring real-device validation in this slice.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Triage tooling must not require app binaries, signing material, secrets, or media bytes.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M10.1 Snapshot Inspector

- [x] Add a local inspector for support snapshot JSON.
- [x] Validate required fields, platform, timestamp, sync object, and redaction markers.
- [x] Reject sensitive marker names outside the redaction section.

### M10.2 Triage Summary

- [x] Print concise Android support summaries.
- [x] Print concise iOS support summaries.
- [x] Support stdin input for pasted snapshots.

### M10.3 Documentation

- [x] Document inspection usage.
- [x] Document validation checks.
- [x] Document support summary contents.

### M10.4 Automated Gate

- [x] Keep snapshot fixture validation, inspector validation, beta preflight, and full M0 checks green.

## Progress Log

### 2026-09-14 M10 Started

Added support snapshot triage tooling:

- `scripts/inspect-support-snapshot.py` validates and summarizes copied support snapshot JSON.
- The inspector supports file input and stdin.
- Documentation captures validation checks and triage summary contents.

### 2026-09-14 M10 Automated Gate Passed

Completed the M10 automated gate:

- `python3 scripts/validate-fixtures.py` passed.
- `python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-android.json` passed.
- `python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-ios.json --summary-only` passed.
- stdin inspection passed.
- sensitive-marker negative validation failed as expected.
- `bash scripts/check-beta-preflight.sh --transport signed-http --full` passed.
