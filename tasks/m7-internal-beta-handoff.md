# M7 - Internal Beta Handoff

Status: Complete after M6 beta package readiness completion on 2026-09-14.

Goal: make internal beta handoff repeatable without running real-device validation in this slice.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Do not commit generated build artifacts, signing files, local SDK paths, secrets, or packaged app binaries.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M7.1 Handoff Record Generator

- [x] Add a script that generates a beta handoff record with commit, versions, transport, readiness gate, and scope notes.
- [x] Keep generated handoff records outside Git by default.
- [x] Add optional artifact checksum recording for external APK/IPA paths.

### M7.2 Package Commands

- [x] Document Android internal APK/AAB build commands and storage expectations.
- [x] Document iOS archive/export expectations without committing signing material.
- [x] Add a package checklist for paired Android/iOS artifact version matching.

### M7.3 Automated Gate

- [x] Keep release-readiness, repo hygiene, and full M0 checks green.

## Progress Log

### 2026-09-14 M7 Started

Started with repeatable handoff traceability:

- Added `scripts/generate-beta-handoff.sh`.
- The script records commit SHA, branch, dirty/clean state, Android/iOS versions, transport mode, release-readiness output, validation status, and product scope boundaries.

### 2026-09-14 M7 Package Notes Added

Expanded the handoff flow:

- Added optional external artifact checksum recording to the handoff generator.
- Added Android package notes, iOS package notes, and paired-version checklist.
- Documented that generated packages and handoff records stay outside Git.

### 2026-09-14 M7 Automated Gate Passed

Completed the M7 automated gate:

- `bash scripts/check-release-readiness.sh --transport signed-http` passed.
- `bash scripts/check-repo-hygiene.sh` passed.
- `bash scripts/generate-beta-handoff.sh --transport signed-http` passed.
- `bash scripts/generate-beta-handoff.sh --transport signed-http --artifact /tmp/sharesync-artifact-test.bin --output /tmp/sharesync-beta-handoff.md` passed.
- `./scripts/check-m0.sh` passed.
