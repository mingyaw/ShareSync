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

- [x] Separate paired device identity from the mutable last-known network endpoint.
- [x] Add local endpoint discovery for paired Android devices.
- [x] Validate discovered or restored endpoints against the paired Android `deviceId` before syncing.
- [x] Add M1 transitional signed local requests.
- [x] Add request timestamp and nonce validation to reduce replay risk.
- [x] Add shared request-signing fixtures.
- [x] Add Android signature verification tests for manifest, media, and sync result endpoints.
- [x] Add iOS signed request generation tests for manifest, media, and sync result requests.
- [x] Replace M0 token-only fallback with signed-request-only authorization for production router wiring.
- [ ] Decide whether local HTTPS is required for M1 or remains a pre-release hardening branch.

### M1.2 Photo Sync History

- [x] Add durable Android sync event records for accepted iOS results.
- [x] Add durable iOS sync event records for fetch, download, import, and result post.
- [x] Show latest sync time on Android.
- [x] Show latest successful sync time on iOS.
- [x] Show latest transferred photo count on Android without requiring copied JSON.
- [x] Show latest transferred photo count on iOS without requiring copied JSON.
- [x] Keep raw JSON copy actions as diagnostics, not primary user feedback.

### M1.3 Repeat Sync Reliability

- [x] Add automated coverage for repeated iOS result posting after app restart.
- [x] Add automated coverage for Android manifest filtering after file-store reload with mixed result states.
- [x] Add iOS coverage for deleted-photo retry after state reload.
- [x] Add iOS coverage for reset controls preserving imported Photos library items while clearing ShareSync state.
- [x] Add Android coverage for clear sync result followed by rebuilt manifest counts.

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

### 2026-09-03 Paired Device Endpoint Refresh

Reduced the need to re-pair when Android receives a different local IP:

- Split the iOS paired session into trusted Android identity plus mutable last-known endpoint.
- Added Android Bonjour/mDNS advertisement for the active local photo sharing endpoint.
- Added iOS local discovery before manifest fetch and sync-all actions.
- Kept saved host and port as fallback when mDNS is unavailable.
- Required `/v1/health.deviceId` to match the trusted Android device before using any discovered or restored endpoint.

### 2026-09-03 Transitional Signed Requests

Started replacing M0 token-only authorization with signed local requests:

- Added a shared signing fixture for the canonical request payload.
- Added Android HMAC-SHA256 request signature validation with timestamp skew and nonce replay protection.
- Updated Android router authorization to require signed requests by default, with token-only auth available only as an explicit legacy validation policy.
- Added iOS request signing for manifest fetch, media download, and sync result post.
- Added Swift tests for signed request headers and Android tests for signature verification and replay rejection.

### 2026-09-03 Signed-Only Production Authorization

Finished the M1 production authorization switch away from token-only requests:

- Added an Android authorization policy so production router construction defaults to signed-request-only.
- Kept token-only fallback behind an explicit legacy validation policy for narrow compatibility tests.
- Added coverage proving token-only manifest requests are rejected by the default router.
- Confirmed the iOS client sends signed headers on all protected photo sync requests.

### 2026-09-03 Android Sync Event History

Started the M1.2 sync history track on Android:

- Added a durable Android sync event store for accepted iOS sync results.
- Persisted the most recent 50 sync events under Android app storage.
- Updated the Android product screen to show the latest sync time, transferred count, skipped count, and retry count without opening raw JSON diagnostics.
- Cleared sync event history together with Android sync result state when the user resets ShareSync state.
- Added Android unit coverage for event summarization, file persistence, retention trimming, and router event recording.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-09-03 iOS Sync Event History

Completed the first iOS side of M1.2 sync history:

- Added a durable iOS sync event store under app support storage.
- Recorded fetch manifest, download, import, and sync result post events.
- Kept the most recent 50 iOS sync events for restart-safe local history.
- Restored the latest successful sync event on app launch.
- Added an iOS status row for latest sync time, completed photo count, and retry count.
- Cleared iOS sync events with the local ShareSync state reset.
- Added Swift tests for result summary, file persistence, retention trimming, and clearing.
- Added the new iOS sync event store to the Xcode app target.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-09-04 Repeat Sync Reliability Coverage

Finished the M1.3 automated reliability slice for repeated photo-only sync:

- Added iOS coverage that a persisted imported photo record can be rebuilt into a sync result after app restart, so result posting can repeat safely.
- Added iOS coverage that an imported photo marked missing after state reload becomes retryable again and no longer reports as an imported mapping.
- Added iOS coverage that ShareSync reset clears only local sync state and imported mappings, leaving Photos library assets outside the reset boundary.
- Added Android coverage that manifest generation reloads file-backed sync results and filters only completed `synced` and `skipped` media.
- Added Android coverage that clearing sync results causes previously completed media to appear in the rebuilt manifest again.
