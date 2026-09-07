# M3 - Pre-Release Product Hardening

Status: Active after M2 main-axis completion on 2026-09-07.

Goal: turn the photo-only ShareSync MVP into a pre-release candidate that is easier to validate, support, and safely evolve, without adding new sync data types or relying on unattended iOS background execution.

## Scope

M3 keeps the main axis focused on Android-to-iOS photo sync:

- Android remains the source device and local transfer server.
- iOS remains the foreground receiver and iCloud Photos gateway.
- The current M2 transport remains signed local HTTP until M3 security work explicitly changes it.
- No cloud relay, Apple ID handling, or third-party storage integration is introduced.
- Product behavior must be explainable through status, recovery guidance, sync history, and validation evidence.

## Success Criteria

- `./scripts/check-m0.sh` stays green.
- README and release-readiness docs clearly describe current support, limits, install/run flow, and validation gates.
- Android and iOS share one recovery matrix for common failure states.
- The app can show a useful recent sync/history summary without depending on logs or copied JSON.
- Reset and persistence behavior are documented and covered by tests where possible.
- M3 security direction is concrete enough to start implementation without revisiting the local-HTTPS decision.

## Main Tasks

### M3.1 Release Readiness Consolidation

- [x] Create M3 release-readiness checklist.
- [x] Separate supported M3 behavior from known limitations.
- [x] Link M0, M1, M2, and M3 validation/readiness documents from README.

### M3.2 Error And Recovery UX Matrix

- [x] Create shared recovery matrix for common Android/iOS failure states.
- [x] Align Android UI copy with shared recovery matrix.
- [x] Align iOS UI copy with shared recovery matrix.
- [x] Add unit coverage for recovery guidance selection where logic exists.

### M3.3 Sync History And Audit View

- [ ] Define cross-platform sync history summary fields.
- [ ] Add iOS history summary model and tests.
- [ ] Add Android history summary model and tests.
- [ ] Surface recent sync history in iOS settings/diagnostics.
- [ ] Surface recent sync history in Android settings/diagnostics.

### M3.4 Persistence And Reset Safety

- [ ] Document all persisted local state and reset semantics.
- [ ] Add iOS tests for clear pairing vs reset local sync state boundaries.
- [ ] Add Android tests for clearing latest result/event state boundaries.
- [ ] Document app delete/reinstall behavior as a known limitation.

### M3.5 Security Implementation Spec

- [ ] Expand QR-pinned certificate implementation spec.
- [ ] Define Android certificate generation/persistence/rotation behavior.
- [ ] Define iOS certificate pinning storage and recovery UX.
- [ ] Decide M3 implementation order for HTTPS vs response signing.

### M3.6 Repo And Build Hygiene

- [ ] Add concise developer quickstart for Android Studio and Xcode.
- [ ] Add local check commands for targeted Android/iOS development.
- [ ] Confirm no private identity, generated build output, or local machine paths are committed.

## Explicit Post-M3 Product Branches

These remain outside M3 unless deliberately pulled into a new milestone:

- Videos.
- Contacts.
- Files and iCloud Documents.
- BLE discovery.
- Reverse sync from iOS to Android.
- Bidirectional merge and conflict UI.
- Fully unattended iOS background sync.
- App Store and Google Play commercial launch.

## Progress Log

### 2026-09-07 M3 Started

Started M3 after completing the M2 photo reliability checklist:

- Kept M3 scoped to pre-release hardening for the existing photo MVP.
- Added release-readiness consolidation as the first task so the repo can communicate current behavior clearly.
- Added error/recovery UX, sync history, persistence/reset safety, security spec, and repo hygiene as the M3 work tracks.

### 2026-09-07 M3 Recovery Guidance

Completed the M3.2 recovery UX alignment slice:

- Added iOS and Android readiness-level recovery guidance enums with unit coverage.
- Updated iOS blocked/error copy to match the recovery matrix for pairing, endpoint, permissions, interruption, local network, and rejected requests.
- Updated Android readiness copy for photo permission, local endpoint availability, pairing, and retry continuation.
