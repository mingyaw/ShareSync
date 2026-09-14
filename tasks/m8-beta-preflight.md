# M8 - Beta Preflight

Status: Complete after M7 internal beta handoff completion on 2026-09-14.

Goal: provide one repeatable preflight command for internal beta handoff without running real-device validation by default.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Real-device validation remains deferred until explicitly resumed.
- Do not commit generated handoff records, app binaries, signing material, local SDK paths, secrets, or build output.

## Tracks

### M8.1 Preflight Script

- [x] Add one beta preflight script that runs release-readiness, repo hygiene, and handoff generation.
- [x] Keep full M0 checks opt-in with `--full`.
- [x] Support external artifact checksum recording through the handoff generator.

### M8.2 Documentation

- [x] Document default preflight usage.
- [x] Document full preflight usage.
- [x] Document artifact checksum handoff usage.

### M8.3 Automated Gate

- [x] Keep `git diff --check`, beta preflight, repo hygiene, and full M0 checks green.

## Progress Log

### 2026-09-14 M8 Started

Added beta preflight automation:

- `scripts/check-beta-preflight.sh` runs whitespace, release-readiness, repo hygiene, and beta handoff generation.
- `--full` adds the full M0 gate for source-code handoff.
- `--artifact` and `--handoff-output` pass through to the M7 handoff generator.

### 2026-09-14 M8 Automated Gate Passed

Completed the M8 automated gate:

- `bash -n scripts/check-beta-preflight.sh` passed.
- `bash scripts/check-beta-preflight.sh --transport signed-http` passed.
- `bash scripts/check-beta-preflight.sh --transport signed-http --artifact /tmp/sharesync-preflight-artifact.bin --handoff-output /tmp/sharesync-preflight-handoff.md` passed.
- `bash scripts/check-beta-preflight.sh --transport signed-http --full` passed.
