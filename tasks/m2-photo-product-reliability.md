# M2 - Photo Product Reliability

Status: Active after M1 completion on 2026-09-04.

Goal: turn the photo-only MVP into a product-reliable local sync experience for repeated personal use, without expanding into videos, contacts, files, reverse sync, or unattended iOS background promises.

## Scope

M2 keeps the main axis focused on photos only:

- Android remains the photo source and local transfer server.
- iOS remains the foreground receiver and iCloud Photos gateway.
- Pairing is durable across ordinary app restarts.
- Network endpoint changes are handled by discovery plus paired-device validation.
- User-facing flow should explain what is ready, blocked, syncing, complete, or retryable.

## Success Criteria

- M0/M1 checks stay green through `./scripts/check-m0.sh`.
- The primary UX can be driven by a single readiness model instead of scattered button logic.
- Android and iOS make blocked states obvious before transfer starts.
- Sync interruption and retry behavior is covered by tests and manual checklist items.
- Release notes clearly separate M2 photo reliability from post-M2 product branches.

## Main Tasks

### M2.1 Sync Readiness Model

- [x] Add iOS photo sync readiness model for pairing, endpoint, port, Photos permission, fetch state, and active transfer.
- [x] Route iOS fetch/sync button enablement through the readiness model.
- [x] Add unit coverage for blocked and ready iOS readiness states.
- [x] Add Android readiness/action model for permission, server state, manifest count, and retry state.
- [ ] Surface readiness reason in primary Android/iOS UI copy.

### M2.2 Guided Product Flow

- [ ] Reduce iOS primary actions to the next best action while keeping diagnostics under settings.
- [ ] Make Android primary screen emphasize QR pairing, photo availability, and latest sync outcome.
- [ ] Add clear blocked-state text for missing Wi-Fi/local network, Photos permission, Android permission, and unexpected paired device.
- [ ] Keep manual endpoint and raw JSON copy tools available only as diagnostics.

### M2.3 Retry And Interruption Hardening

- [ ] Add coverage for iOS cancellation followed by sync-all resume.
- [ ] Add coverage for post-result failure followed by next successful post.
- [ ] Add Android coverage for multiple iOS result posts across batches.
- [ ] Add manual checklist for app foreground/background transitions during large photo sync.

### M2.4 Validation Evidence

- [ ] Add dedicated M2 physical-device validation results file.
- [ ] Record required device matrix for Android/iPhone OS versions.
- [ ] Track pass/fail evidence for single photo, all photos, deleted-photo retry, reset, and app restart.

### M2.5 Pre-Release Security Branch Prep

- [ ] Document local HTTPS threat model and certificate UX options.
- [ ] Decide whether local HTTPS lands in M2 or a dedicated M3 security milestone.
- [ ] Keep signed local HTTP as the tested M2 implementation until HTTPS is explicitly pulled in.

## Post-M2 Product Branches

These remain outside the active M2 photo reliability main axis:

- Videos.
- Contacts.
- Files and iCloud Documents.
- BLE discovery.
- Reverse sync from iOS to Android.
- Bidirectional merge and conflict UI.
- Fully unattended iOS background sync.
- App Store and Google Play commercial launch.

## Progress Log

### 2026-09-04 M2 Started

Started M2 after completing the M1 photo MVP hardening checklist:

- Kept the main axis photo-only.
- Prioritized product reliability and guided UX over new sync data types.
- Added the first iOS sync readiness model so product actions can be driven by explicit blocked/ready states.
- Added the matching Android readiness/action model for permission, server, manifest, complete, and retry states.
