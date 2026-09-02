# M1 - Photo MVP Hardening

Status: Active after M0 completion on 2026-09-02.

Goal: turn the completed M0 Android-to-iOS photo PoC into a photo-only MVP that is safer, clearer, and easier to operate repeatedly on real devices.

## Scope

M1 keeps the main axis focused on photos only:

- Android MediaStore photos as the source.
- Android local server as the transfer endpoint.
- iOS foreground receiver as the reliable import path.
- iOS Photos as the iCloud gateway.
- Local transfer only, with no cloud relay.

## Success Criteria

- M0 photo flow remains green through `./scripts/check-m0.sh`.
- Pairing and transfer security are upgraded beyond the temporary M0 token model.
- Android and iOS expose enough sync history for users to understand what happened without copying JSON.
- Repeated sync runs stay predictable after app restart, network change, interruption, and user reset.
- M1 does not introduce videos, contacts, files, reverse sync, or unattended iOS background promises.

## Main Tasks

### M1.1 Security Hardening

- [ ] Replace M0 token-only protection with signed local requests.
- [ ] Add request timestamp or nonce validation to reduce replay risk.
- [ ] Add shared request-signing fixtures.
- [ ] Add Android signature verification tests for manifest, media, and sync result endpoints.
- [ ] Add iOS signed request generation tests.
- [ ] Decide whether local HTTPS is required for M1 or remains a pre-release hardening branch.

### M1.2 Photo Sync History

- [ ] Add durable Android sync event records for accepted iOS results.
- [ ] Add durable iOS sync event records for fetch, download, import, and result post.
- [ ] Show latest successful sync time on Android.
- [ ] Show latest successful sync time on iOS.
- [ ] Show latest transferred photo count without requiring copied JSON.
- [ ] Keep raw JSON copy actions as diagnostics, not primary user feedback.

### M1.3 Repeat Sync Reliability

- [ ] Add automated coverage for repeated iOS result posting after app restart.
- [ ] Add automated coverage for Android manifest filtering after file-store reload with mixed result states.
- [ ] Add iOS coverage for deleted-photo retry after state reload.
- [ ] Add iOS coverage for reset controls preserving imported Photos library items while clearing ShareSync state.
- [ ] Add Android coverage for clear sync result followed by rebuilt manifest counts.

### M1.4 Product UI Polish

- [x] Rename M0-facing labels to product-facing photo sync labels.
- [x] Reduce validation-only controls or group them under diagnostics.
- [x] Add clearer empty states for no photos, all synced, and retry required.
- [x] Add short user-facing explanations for iOS foreground requirements.
- [x] Keep manual endpoint and JSON copy tools available for diagnostics.

### M1.5 Release Readiness

- [ ] Update privacy copy for local photo transfer and Photos import.
- [x] Update permission rationale copy for Android photos, Android notifications, iOS camera, iOS Photos, and local network.
- [ ] Add setup notes for release/debug build variants.
- [ ] Add M1 manual regression checklist.
- [ ] Keep post-M1 product branches explicitly separated.

## Post-M1 Product Branches

These remain outside the active photo MVP main axis:

- Videos.
- Contacts.
- Files and iCloud Documents.
- BLE discovery.
- Reverse sync from iOS to Android.
- Bidirectional merge.
- Fully unattended iOS background sync.
- App Store and Google Play commercial release work.

## Progress Log

### 2026-09-02 M1 Planning Started

Started the M1 photo MVP hardening track after M0 completion:

- Kept M1 focused on the photo-only Android-to-iOS/iCloud gateway path.
- Split post-M0 work into security, history, repeat reliability, UI polish, and release-readiness slices.
- Parked videos, contacts, files, BLE discovery, reverse sync, bidirectional merge, and unattended iOS background sync as post-M1 product branches.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-09-02 Product UI Polish

Made the photo MVP feel closer to an actual product while keeping diagnostic tools available:

- Updated the iOS receiver into a structured ShareSync photo workflow with header, transfer summary, primary actions, connection setup, status, and diagnostics sections.
- Added clearer iOS states for pairing required, ready to fetch, ready to transfer, active transfer, retry, no photos, and complete.
- Added explicit foreground guidance on iOS so the user understands why ShareSync should stay open during transfer.
- Updated Android strings from M0/test-server wording to photo sync product wording.

### 2026-09-02 Traditional Chinese And English Localization

Added the first product localization pass:

- Added Android English defaults and Traditional Chinese `values-zh-rTW` strings.
- Added iOS English and Traditional Chinese `Localizable.strings`.
- Added iOS English and Traditional Chinese `InfoPlist.strings` for camera, local network, and Photos permission prompts.
- Localized the current iOS product UI, QR scanner, and primary user-facing error messages.

### 2026-09-02 Pairing-First UX Flow

Moved the MVP closer to the intended product flow:

- Android now auto-starts photo sharing after photo permission is available and presents pairing QR/status as the primary screen.
- Android manual server controls, endpoint copy, raw pairing payload, sync result JSON, and reset actions are grouped under settings/diagnostics.
- iOS now shows pairing first when no Android device is configured.
- iOS shows the photo sync workflow after pairing, with auto-sync-all enabled by default and manual sync-all still available.
- iOS advanced connection, status, and diagnostics controls are tucked behind a settings disclosure.
