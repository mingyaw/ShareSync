# M15 Support Snapshot Inspector Tests

Status: Complete support snapshot inspector regression tests for beta preflight.

M15 turns the support snapshot inspector's most important positive and negative checks into a repeatable local gate. The goal is to keep beta diagnostics dependable while real-device validation remains deferred.

## Validation Behavior

The new `scripts/test-support-snapshot-inspector.sh` gate checks:

- Valid Android and iOS support snapshot fixtures pass.
- A snapshot missing `nextStep` fails.
- Android snapshots reject iOS-only next-step action codes.
- iOS snapshots reject Android-only next-step action codes.
- Sensitive pairing or signing markers outside `redaction` fail.

## Gate Integration

The support snapshot inspector regression gate now runs from:

- `scripts/check-m0.sh`
- `scripts/check-beta-preflight.sh`

This means main-axis validation covers both generated fixture compatibility and the local triage tool used during internal beta support.

## Scope Reminder

M15 remains limited to the photo-only MVP:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only.
- No cloud relay.
- No direct iCloud API.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
- Real-device validation remains deferred until explicitly resumed.
