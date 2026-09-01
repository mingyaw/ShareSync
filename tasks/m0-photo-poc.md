# M0 - Android to iOS Photo PoC

Goal: prove that iPhone can pull photos from Android over a local network and import them into iOS Photos without duplicate imports.

## Success Criteria

- Android displays a QR payload with local IP, port, device id, and pairing token.
- iOS parses the QR payload.
- iOS fetches `GET /v1/manifest`.
- Manifest includes up to 100 recent Android photos.
- iOS downloads photos from `GET /v1/media/{assetId}`.
- iOS imports photos into a `ShareSync Backup` album.
- Re-running M0 does not duplicate already imported photos.
- Interrupted downloads can resume or skip already completed items.
- Errors surface clear codes from `shared/protocol/error-codes.md`.

## Android Tasks

### Current Android Progress

- [x] Add M0 sync data models.
- [x] Add pairing payload factory.
- [x] Add manifest builder.
- [x] Add manifest JSON encoder.
- [x] Add local API router core for health, manifest, and media response metadata.
- [x] Add MediaStore-backed scanner.
- [x] Restrict active M0 scope to Android photos only.
- [x] Add MediaStore-backed media lookup provider.
- [x] Add media stream provider for content URIs.
- [x] Bind router to a real Android embedded HTTP server.
- [x] Connect media stream provider to real HTTP response bodies.
- [x] Add app-level M0 sync component factory.
- [x] Add Android UI controls to request photos permission and start/stop server.
- [x] Show Android local IP/port for manual testing.
- [x] Add Android endpoint copy action for same-network validation.
- [x] Show Android pending manifest photo count for manual validation.
- [x] Keep Android screen awake while the M0 server is running.
- [x] Start an Android foreground data-sync service while the M0 server is running.

### A1. Project Setup

- [x] Create Android Studio project under `android/`.
- [x] Configure Kotlin.
- [x] Add app id, min SDK, target SDK.
- [x] Add local network and photos permissions.

### A2. Device Identity

- [x] Generate stable device id.
- [x] Generate key pair placeholder for M0.
- [x] Store identity locally.

### A3. Pairing Payload

- [x] Resolve current local IP.
- [x] Start local server on available port.
- [x] Generate QR payload from `PairingPayloadFactory`.
- [x] Render QR code in Android UI.

### A4. Media Scanner

- [x] Implement `MediaScanner` using MediaStore.
- [x] Query latest 100 images from MediaStore.
- [x] Map rows into `MediaAsset`.
- [x] Add lazy SHA-256 calculation before transfer.

### A5. Local Server

- [x] Implement `GET /v1/health`.
- [x] Implement `GET /v1/manifest`.
- [x] Implement `GET /v1/media/{assetId}`.
- [x] Implement `POST /v1/sync/result`.
- [x] Enforce pairing-token header on protected M0 endpoints.
- [x] Persist latest sync result on Android.
- [x] Show latest sync result summary on Android M0 screen.
- [x] Show latest failed result code on Android M0 screen.
- [x] Restore latest Android sync result summary on app launch.
- [x] Show Android phase for permission, server start, pairing, retry, and completion validation.
- [x] Add Android copy action for latest sync result JSON.
- [x] Show Android manifest transfer status for ready, retry, or complete validation.
- [x] Keep Android sync result polling active while the M0 server is running.
- [x] Exclude latest synced/skipped media results from Android manifest.
- [x] Merge Android sync results across multiple M0 batches.
- [x] Add Android validation control to clear persisted M0 sync result state.
- [x] Extract Android M0 runtime phase and manifest status rules into a tested model.
- [x] Add range request support.
- [x] Return `416 Range Not Satisfiable` for invalid Android media ranges.
- [x] Add basic error responses.

## iOS Tasks

### Current iOS Progress

- [x] Add Swift Package for core testability.
- [x] Add sync models.
- [x] Add pairing payload parser.
- [x] Add manifest client.
- [x] Add photo importer interface.
- [x] Add media download state model and in-memory state store.
- [x] Add tests for pairing payload parsing.
- [x] Add tests for manifest decoding.
- [x] Add tests for media download state transitions.
- [x] Add manual Android endpoint form for manifest fetch.
- [x] Implement single-item media downloader validation path.
- [x] Implement single-item PhotoKit import path.
- [x] Implement QR scanner UI.
- [x] Add iOS clear-pairing control for stale M0 endpoint/token recovery.
- [x] Add iOS copy action for latest generated sync result JSON.

### I1. Project Setup

- [x] Create Swift Package core under `ios/ShareSync`.
- [x] Create Xcode app project under `ios/`.
- [x] Configure SwiftUI app target.
- [x] Add camera permission for QR scanning.
- [x] Add Photos permission.
- [x] Add local network permission.

### I2. QR Pairing

- [x] Implement QR scanner.
- [x] Persist iOS paired Android endpoint and M0 token across app restarts.
- [x] Clear stale iOS paired Android endpoint and M0 token without deleting the app or sync result evidence.
- [x] Parse payload using `PairingPayloadParser`.
- [x] Show paired Android device.
- [x] Restore last paired Android device on iOS app launch.

### I3. Manifest Client

- [x] Use `ManifestClient` to fetch Android manifest.
- [x] Preflight Android `/v1/health` before manifest fetch.
- [x] Use explicit local-network timeouts for health, manifest, result posts, and media downloads.
- [x] Show total photo count and total byte size.
- [x] Show latest cursor in the M0 receive screen.

### I4. Media Download

- [x] Download one photo file to app temp directory for validation.
- [x] Verify SHA-256 when available.
- [x] Track per-asset download state.
- [x] Expand UI action from single-item validation to batch download.
- [x] Add all-remaining manifest download action for M0 device validation.
- [x] Show iOS receive phase for pairing, fetch, transfer, retry, and completion validation.
- [x] Show manifest transfer status for ready, retry, complete, or no-photo validation.
- [x] Show live foreground batch progress during iOS transfer.
- [x] Keep iPhone screen awake during active foreground transfer.
- [x] Pause iOS foreground transfer when the app leaves the foreground.
- [x] Add manual foreground transfer stop and retry support.
- [x] Resume or skip completed items after restart.
- [x] Show resumable partial photo count on iOS receive screen.
- [x] Add iOS Range request path for persisted partial media retries.
- [x] Retry one transient network download failure before marking a photo failed.
- [x] Remove temporary downloaded photo files after successful Photos import.

### I5. Photos Import

- [x] Request Photos permission.
- [x] Show Photos permission status before transfer.
- [x] Create `ShareSync Backup` album.
- [x] Import one downloaded photo for validation.
- [x] Store Android asset id to iOS local identifier mapping.
- [x] Prevent duplicate imports.
- [x] Treat missing imported Photos assets as retryable transfer candidates.
- [x] Persist latest shared `SyncResult` JSON.
- [x] Restore latest shared `SyncResult` JSON on iOS app launch.
- [x] Copy latest shared `SyncResult` JSON from the iOS receive screen.
- [x] POST latest `SyncResult` back to Android M0 server.
- [x] Add iOS validation control to clear local M0 download/import/result state.

## Cross-Platform Tasks

- [x] Add shared sample pairing payload fixture.
- [x] Add shared sample manifest fixture.
- [x] Add lightweight fixture validation script.
- [x] Add one-command M0 validation script.
- [x] Validate generated manifest against `shared/schemas/manifest.schema.json`.
- [x] Keep fixture date encoding ISO-8601.
- [x] Keep fixture enum values lowercase.
- [x] Align item status values with `sync-result.schema.json`.
- [x] Validate sample sync result fixture against `shared/schemas/sync-result.schema.json`.
- [x] Add sync result comparison script for iOS and Android copied JSON.
- [x] Validate M0 results tracker status values and completion gate scenarios.

## Test Matrix

- [ ] iPhone foreground, Android foreground.
- [ ] iPhone lock screen during download.
- [ ] Android app backgrounded during transfer.
- [ ] Same Wi-Fi.
- [ ] Android hotspot.
- [ ] Transfer interrupted midway.
- [x] iOS app restart after pairing.
- [x] Stale iOS pairing reset.
- [ ] Repeat sync.
- [x] No Photos permission.
- [x] iPhone storage low.

## Manual M0 Device Validation

Run the full checklist in `docs/m0-device-validation.md` and record real-device results in `docs/m0-validation-results.md` before calling M0 complete.

## Out of Scope for M0

- Contacts.
- Files.
- BLE discovery.
- Background URLSession tuning.
- Full HTTPS certificate handling.
- Full request signing.
- App Store release.

## Progress Log

### 2026-09-01 Android M0 Foreground Service

Completed an Android background-transfer support slice:

- Added `AndroidM0ForegroundService` with a low-importance M0 photo transfer notification channel.
- Declared the Android foreground service permissions and `dataSync` service type.
- Started the foreground service after the local M0 server successfully binds, and stopped it when the server stops or start fails.

Verified:

```sh
./gradlew :app:testDebugUnitTest :app:compileDebugKotlin :app:processDebugMainManifest
./scripts/check-m0.sh
```

### 2026-09-01 Android M0 Runtime State Model

Completed an Android M0 service-readiness slice:

- Added `AndroidM0RuntimeState` for phase and manifest transfer status rules.
- Kept MainActivity responsible for UI text while moving state decisions into testable Kotlin.
- Added Android unit coverage for permission, server starting, ready, retry, and transfer-complete states.

Verified:

```sh
./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
```

### 2026-08-26 iOS Clear Pairing Control

Completed a small M0 reliability slice:

- Added an iOS `Clear Pairing` action for stale Android M0 endpoint/token recovery.
- Kept pairing reset separate from local download/import/result state reset.
- Documented the stale-pairing validation path and reset semantics.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 M0 Validation Results Tracking

Completed an M0 completion-readiness slice:

- Added a real-device validation results tracker.
- Defined pass/fail/blocking statuses for each M0 scenario.
- Linked M0 completion to recorded validation evidence.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 iOS Transfer Status

Completed an M0 receive-screen validation slice:

- Added a manifest-level `Transfer` status on iOS.
- Made repeat-sync validation easier to read with `Ready`, `Needs Retry`, `Complete`, and `No Photos` states.
- Updated M0 validation steps to check the transfer status during baseline and repeat sync.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 Android Sync Result Copy

Completed an Android M0 validation aid:

- Added `Copy sync result` for the latest Android-persisted iOS report JSON.
- Kept the action disabled until Android has a sync result.
- Updated validation steps and run-log template to capture sync result evidence.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 Android Manifest Transfer Status

Completed an Android M0 validation slice:

- Added manifest transfer status to the Android M0 screen.
- Show `Ready`, `Needs retry`, or `Complete` next to pending manifest photo count.
- Updated validation steps to confirm Android reaches `0 pending, Complete` after synced/skipped results filter the manifest.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-27 iOS Sync Result Copy

Completed an iOS M0 validation aid:

- Restored the latest persisted sync result summary on iOS app launch.
- Added a `Copy Sync Result` action for the latest iOS-generated result JSON.
- Updated validation steps so iOS and Android result JSON can be compared during real-device runs.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-27 Sync Result Compare Tool

Completed a cross-platform validation tool:

- Added `scripts/compare-sync-results.py` for comparing iOS and Android copied sync result JSON.
- The tool validates the basic shared result shape before canonical comparison.
- Added the comparison tool to `./scripts/check-m0.sh` using the sample sync result fixture.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-27 Clear Pairing Result Evidence

Completed a small iOS state-consistency fix:

- Kept latest sync result summary visible after clearing stale pairing.
- Preserved copied-result evidence separately from pairing endpoint/token state.
- Updated reset semantics in README and M0 validation docs.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-27 iOS Receive Phase

Completed a small iOS validation-readiness slice:

- Added a concise `Phase` row to the receive screen.
- Covered pairing, fetch, transfer, retry, no-photo, completion, and error states.
- Updated M0 validation steps to use phase status during baseline and repeat-sync checks.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-27 Android M0 Phase

Completed an Android validation-readiness slice:

- Added a concise `Phase` row to the Android M0 screen.
- Covered permission, server starting, ready-to-start, ready-to-pair, retry, and completion states.
- Updated M0 validation steps to check Android phase during baseline and full-manifest validation.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-27 M0 Results Tracker Validation

Completed a validation-document guard:

- Added `scripts/validate-m0-results.py`.
- Checks allowed status values in the M0 validation results table.
- Checks that every required M0 completion-gate scenario is represented.
- Added the results tracker validation to `./scripts/check-m0.sh`.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-20

Completed a lightweight implementation slice:

- Shared sample fixtures for pairing payload and manifest.
- `scripts/validate-fixtures.py` for local JSON/fixture sanity checks.
- Swift Package setup for iOS core.
- Swift tests for QR pairing payload parsing and manifest decoding.
- Android manifest JSON encoder.
- Android local API router core for `/v1/health`, `/v1/manifest`, and media response metadata.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
```

Follow-up target at the time:

- Bind Android `LocalSyncRouter` to an embedded HTTP server.
- Implement Android MediaStore scanner.
- Add iOS media download state tracking.

### 2026-08-20 Project Shells

Completed native IDE project shells:

- Android Studio project under `android/`.
- Minimal Android `MainActivity`.
- Android app resources, manifest, and Gradle build files.
- Xcode app project at `ios/ShareSync.xcodeproj`.
- Minimal SwiftUI app shell under `ios/ShareSyncApp`.
- Xcode app target includes existing iOS core files.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
xcodebuild -list -project ios/ShareSync.xcodeproj
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
cd android && ./gradlew :app:assembleDebug
```

### 2026-08-20 Media Scan And Download State

Completed another M0 implementation slice:

- Android `MediaStoreMediaScanner` for recent photo metadata.
- Android `MediaProvider` implementation through the scanner.
- Android `MediaStreamProvider` for opening content URI streams.
- Internal Android `contentUri` field on `MediaAsset`, intentionally excluded from manifest JSON.
- iOS `MediaDownloadRecord`, `MediaDownloadStatus`, and `MediaDownloadStateStore`.
- In-memory iOS download state store for queue/download/import/failure tracking.
- Swift tests for media download state transitions and requeue behavior.

Verified:

```sh
cd android && ./gradlew :app:assembleDebug
swift test
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-20 Android Local Server Controls

Completed the Android app-level M0 server controls:

- Runtime photos permission request.
- Local IPv4 detection.
- Start/stop controls for the embedded Android local sync server.
- Health endpoint display for manual same-Wi-Fi testing.
- App-level sync component factory used by `MainActivity`.

Verified:

```sh
cd android && ./gradlew :app:assembleDebug
```

### 2026-08-20 iOS Manual Manifest Fetch

Completed the first iOS-to-Android app integration slice:

- Manual Android IP and port entry on the iOS receive screen.
- `ManifestFetchViewModel` wrapper around `ManifestClient`.
- Manifest fetch status, item counts, total byte size, and cursor display.
- M0 local HTTP allowance in the generated iOS app Info.plist settings.

Verified:

```sh
swift test
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Next implementation slice:

- Add Android-to-iOS physical-device manual manifest test notes after the next device run.
- Implement iOS PhotoKit importer for downloaded files.

### 2026-08-20 Embedded Android HTTP Server

Completed another M0 implementation slice:

- Android `EmbeddedLocalSyncServer` using `ServerSocket`.
- `GET /v1/health` response path.
- `GET /v1/manifest` response path.
- `GET /v1/media/{assetId}` response path with range support.
- Media response body streaming from `MediaStreamProvider`.
- Basic JSON error responses for missing media and unsupported methods.
- `EmbeddedLocalServerBinder` to create server instances.
- `M0SyncComponents` factory to wire MediaStore scanner, manifest builder, router, stream provider, and server binder.

Verified:

```sh
cd android && ./gradlew :app:assembleDebug
python3 scripts/validate-fixtures.py
swift test
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Next implementation slice:

- Add Android-to-iOS physical-device manual manifest test notes after the next device run.
- Implement iOS PhotoKit importer for downloaded files.

### 2026-08-20 Android M0 Server Controls

Completed another M0 implementation slice:

- Android photos permission request flow.
- Local IPv4 discovery helper.
- Android M0 control panel with:
  - permission status
  - manual `/v1/health` endpoint
  - server status
  - start server button
  - stop server button
- App-level start/stop wiring for `EmbeddedLocalSyncServer`.
- Stable M0 device id using `Settings.Secure.ANDROID_ID`.

Manual test path after installing the Android app:

```text
1. Grant photos permission.
2. Tap Start M0 server.
3. Open the displayed http://<android-ip>:48291/v1/health endpoint from another device on the same Wi-Fi.
4. Test http://<android-ip>:48291/v1/manifest after photos permission is granted.
```

Verified:

```sh
cd android && ./gradlew :app:assembleDebug
python3 scripts/validate-fixtures.py
swift test
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Next implementation slice:

- Add Android-to-iOS physical-device manual manifest test notes after the next device run.
- Implement iOS PhotoKit importer for downloaded files.

### 2026-08-20 iOS Single-Item Media Downloader

Completed the first iOS media download validation slice:

- `MediaDownloader` for `GET /v1/media/{assetId}` downloads.
- Local file writes into the app temp download directory.
- Optional SHA-256 verification when Android manifest provides a hash.
- State-store integration for queued, downloading, downloaded, and failed records.
- SwiftUI receive screen action to download only the first manifest photo.
- Test item filename display for physical-device validation.
- Downloaded and failed counts on the receive screen.
- Unit tests for successful file write and checksum mismatch failure.

Verified:

```sh
swift test
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Next implementation slice:

- Validate single Android-to-iOS media download on physical devices.
- Expand to selectable or batch media download after single-item validation passes.
- Persist download/import state across app restarts.

### 2026-08-20 iOS Single-Item Photo Import

Completed the first Photos import validation slice:

- `PhotoKitPhotoImporter` implementation behind the existing `PhotoImporter` protocol.
- Photos read/write permission request for album management.
- `ShareSync Backup` album creation or reuse.
- Single downloaded photo import into the backup album.
- Receive screen state updates for importing and imported counts.
- Import success marks the single validation asset as imported in the state store.

Verified:

```sh
swift test
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Next implementation slice:

- Validate single Android-to-iOS download and Photos import on physical devices.
- Store Android asset id to iOS local identifier mapping for duplicate prevention.

### 2026-08-24 M0 Main Path Ready For Device Validation

Completed the main implementation path needed before broad real-device testing:

- Android stable device identity persisted locally.
- Android M0 server fallback to an available port when `48291` is occupied.
- Android lazy SHA-256 calculation returned through `X-ShareSync-SHA256` for full media downloads.
- iOS QR pairing flow and manual pairing fallback.
- iOS batch download action for the next pending items.
- iOS file-backed download/import state store.
- iOS imported Photos mapping with source device id, source asset id, source hash, and Photos local identifier.
- iOS deleted-photo reconciliation that makes removed Photos imports eligible for re-sync.
- Shared fixture validation against schema files.
- Manual real-device acceptance checklist in `docs/m0-device-validation.md`.

Verified:

```sh
python3 scripts/validate-fixtures.py
cd android && ./gradlew :app:compileDebugKotlin
swift test
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Next implementation slice:

- Run the full `docs/m0-device-validation.md` checklist on physical Android/iPhone devices.
- Record any device-only failures before moving to product branches such as contacts, files, BLE discovery, or background scheduling.

### 2026-08-24 iOS Sync Result Summary

Completed a validation/reporting slice for the M0 main path:

- Added iOS `SyncResultBuilder` to convert terminal media download/import records into shared `SyncResult`.
- Added iOS receive-screen sync result counts for synced, skipped, and failed records.
- Added a shared `sample-sync-result.json` fixture and schema validation.
- Aligned iOS media/import error codes with `shared/protocol/error-codes.md`.
- Added protocol entries for Android local media server error responses.
- Fixed the Xcode project source reference for the new sync result builder without breaking QR scanner compilation.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 iOS Latest Sync Result Persistence

Completed a persistence slice for M0 validation:

- Added `FileSyncResultStore` to persist the latest shared `SyncResult` JSON under app support data.
- Wired iOS manifest/download/import state updates to save the latest sync result.
- Added unit tests for latest sync result save, load, and overwrite behavior.
- Documented the validation artifact path in `docs/m0-device-validation.md`.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 Sync Result Return Path

Completed the first local return path for M0:

- Added Android `SyncResultJsonCodec` for shared sync result JSON.
- Added Android `SyncResultStore` and M0 in-memory latest-result storage.
- Added Android `POST /v1/sync/result` handling with `202 Accepted` response for valid results.
- Added iOS `SyncResultClient` to POST saved results back to Android.
- Wired iOS result publishing after manifest/download/import state updates.
- Updated local API contract and device validation checklist.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 Android Sync Result Persistence

Completed the Android-side validation visibility slice:

- Added `FileSyncResultStore` for Android latest sync result persistence.
- Switched M0 Android components from in-memory sync result storage to app file storage.
- Added Android M0 screen summary for latest sync batch, synced count, skipped count, and failed count.
- Added short polling after server start so the Android screen reflects iOS result posts during manual validation.
- Kept shared sync result JSON fields explicit when values are `null`.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 Android Manifest Completion Filtering

Completed the first Android-side use of returned sync results:

- Android manifest builder reads latest sync result state.
- Media reported as `synced` or `skipped` is excluded from the next M0 manifest.
- Media reported as `failed` remains in the manifest so iOS can retry.
- Manifest scanning now looks beyond the requested return limit before filtering completed items.
- Added Android JVM unit tests for completion filtering behavior.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 Android Multi-Batch Sync Result Merge

Completed the multi-batch result merge behavior:

- Android sync result store now merges incoming batches instead of replacing all previous results.
- Completed media from earlier batches remains available for manifest filtering.
- Later results for the same item replace earlier item status.
- Added Android JVM unit tests for in-memory and file-backed merge behavior.

Verified:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 iOS Remaining Batch Validation Control

Completed another M0 validation slice:

- Added an iOS `Download Remaining` action to transfer every remaining item in the current manifest.
- Added an iOS remaining item count to the receive screen.
- Made imported Photos assets marked as `missing` retryable by the next iOS transfer pass.
- Updated M0 manual flow notes for the all-remaining foreground transfer validation.

Verification target:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 iOS Foreground Batch Progress

Completed another M0 validation slice:

- Added per-batch progress reporting to the iOS media downloader.
- Added iOS receive screen rows for batch progress, batch downloaded count, batch failed count, and current file.
- Added Swift unit coverage for progress events across a mixed success/failure batch.
- Updated the foreground full manifest transfer checklist to verify live progress during long transfers.

Verification target:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-24 iOS Manual Transfer Stop

Completed another M0 interrupted-transfer slice:

- Added cancellation-aware behavior to the iOS media downloader.
- Cancellation keeps completed downloads and leaves in-progress items retryable instead of marking them as failed.
- Added a `Stop Transfer` control on the iOS receive screen.
- Added an explicit stopped state message for M0 validation.
- Added Swift unit coverage for cancellation leaving an item retryable.
- Updated the M0 validation checklist with a manual stop and retry scenario.

Verification target:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-25 M0 Pairing Token Enforcement

Completed a lightweight security bridge toward the photo-only MVP:

- Android M0 server now requires `X-ShareSync-Pairing-Token` for manifest, media, and sync result endpoints.
- Android keeps `/v1/health` public for local connectivity diagnostics.
- Android QR payload and protected endpoint validator share the same short-lived server token.
- iOS stores the token from the pairing payload and sends it with manifest, media download, and sync result requests.
- iOS manifest fetch now reports token rejection as a re-pairing action instead of a generic decode failure.
- Added Android router tests and Swift client tests for pairing-token headers.

Verification target:

```sh
python3 scripts/validate-fixtures.py
swift test
cd android && ./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 2026-08-25 Photo-Only MVP Scope

Aligned the active M0/MVP path with the product decision to ship photos first:

- Android M0 manifest now includes `MediaType.photo` only.
- Android MediaStore scanner queries images only and rejects direct video lookups for M0 media endpoints.
- Android 13+ runtime permission now requests `READ_MEDIA_IMAGES` without `READ_MEDIA_VIDEO`.
- Removed MediaStore query-bundle `QUERY_ARG_LIMIT` usage and takes the first N rows in app code to avoid provider `Invalid token LIMIT` failures.
- iOS receive-screen copy and manifest status now present the flow as Android photo transfer.
- Updated M0 validation notes and project docs to distinguish the active photo MVP from later video/contact/file expansion.

### 2026-08-25 Download Error Code Preservation

Improved M0 photo transfer diagnostics:

- iOS media downloader now decodes Android JSON error responses from failed media downloads.
- Failed photo records preserve server error codes such as `SS-AUTH-001` and `SS-MEDIA-404`.
- Sync result reporting can now return more precise failed-item reasons to Android.
- Added Swift tests for unauthorized and missing media download responses.

### 2026-08-25 Receive Screen Failure Visibility

Improved real-device validation feedback:

- iOS manifest summary now tracks the latest failed photo code and file name.
- Receive screen shows `Last Failure` when a manifest item is in failed state.
- Download empty-state messages now use photo-specific wording.
- Device validation checklist now asks testers to confirm `Last Failure` during endpoint errors.

### 2026-08-25 Android M0 Validation Visibility

Improved Android-side manual validation:

- Android M0 screen now shows the current pending manifest photo count after server start.
- Android polling refreshes the pending count after iPhone sync result posts, so manifest filtering can be checked without leaving the app.
- Android sync result summary now includes the latest failed error code when available.
- Android M0 screen is scrollable so QR, payload, and validation rows stay reachable on smaller phones.

### 2026-08-26 iOS Low Storage Failure Code

Completed the low-storage handling slice:

- iOS media downloader checks available destination volume capacity before writing a downloaded photo.
- Insufficient space marks the item failed with `SS-STORE-001`.
- Added Swift coverage to confirm low storage does not write a partial local file.
- Added a low-storage validation scenario to the M0 device checklist.

### 2026-08-26 Checksum Mismatch Retry

Completed the hash mismatch retry slice:

- iOS media downloader now retries one time after a checksum mismatch.
- A successful retry marks the photo downloaded and avoids a false failed record.
- Repeated checksum mismatch still fails with `SS-MEDIA-001`.
- Added Swift coverage for a bad first response followed by a valid retry.
- Added a development validation scenario for hash mismatch retry.

### 2026-08-26 Transient Download Retry

Completed the transient network retry slice:

- iOS media downloader now retries one time after `networkConnectionLost`, `timedOut`, or `cannotConnectToHost`.
- User or system cancellation is still treated as a paused retryable item, not a failed photo.
- Added Swift coverage for network retry recovery and cancelled transfer non-retry behavior.

### 2026-08-26 Photos Permission Preflight

Completed the Photos permission preflight slice:

- Added a shared `PhotoLibraryPermissionStatus` contract for Photos import readiness.
- iOS receive screen now shows `Photos Access` before transfer.
- iOS requests Photos permission before downloading photos, so denied/restricted access stops early instead of downloading files that cannot be imported.
- Added Swift coverage for allowed and blocked Photos permission statuses.

### 2026-08-26 Android Health Preflight

Completed the local network health preflight slice:

- Added an iOS `HealthClient` for Android `GET /v1/health`.
- iOS now checks Android peer health before fetching the protected manifest endpoint.
- Receive screen shows a ready Android peer with device id and protocol version after a successful health check.
- Added Swift coverage for health decode, non-successful responses, and non-ready peer status.

### 2026-08-26 iOS Foreground Awake Guard

Completed the foreground awake guard slice:

- iOS disables the idle timer while photo download or Photos import is active.
- iOS restores normal screen locking when transfer stops, completes, fails, or the receive screen disappears.
- Receive screen shows `Screen Lock` as paused during active foreground transfer for device validation.

### 2026-08-26 Temporary Download Cleanup

Completed the temporary download cleanup slice:

- iOS removes temporary downloaded files after successful Photos import.
- Imported media records no longer retain app temp file URLs.
- Downloaded-but-not-imported records still retain their temp file URLs so restart resume can continue import.
- Added Swift coverage for imported records clearing local temp file references.

### 2026-08-26 Android Sync Result Polling

Completed the Android sync result polling slice:

- Android now keeps polling the latest iOS sync result while the M0 server is running.
- Stopping the M0 server interrupts the polling thread and clears server-scoped UI state.
- This keeps the Android receive summary useful during longer full-manifest photo transfers.

### 2026-08-26 Android Foreground Awake Guard

Completed the Android foreground awake guard slice:

- Android applies `FLAG_KEEP_SCREEN_ON` while the M0 server is running.
- Android clears the keep-awake flag when the server stops.
- Android M0 screen shows whether screen lock is normal or paused for device validation.

### 2026-08-26 Android Endpoint Copy

Completed the Android endpoint copy slice:

- Android M0 screen now has a `Copy endpoint` action for the current `/v1/health` URL.
- The copied endpoint uses the actual bound port, including fallback ports.
- Updated README and device validation notes for same-network and hotspot checks.

### 2026-08-26 iOS Background Pause

Completed the iOS background pause slice:

- iOS now cancels active foreground photo transfer when ShareSync leaves the foreground.
- The receive screen shows a background-specific pause message.
- Completed items are kept and remaining photos stay retryable when the user returns.

### 2026-08-26 Local Network Timeouts

Completed the local-network timeout slice:

- Added a shared iOS local-network URLSession factory.
- Health, manifest, and sync-result requests use short local timeouts.
- Photo media downloads use longer resource timeouts for larger images.
- Sessions wait for connectivity and allow hotspot or constrained network paths during M0 validation.
- Added Swift coverage for timeout configuration.

### 2026-08-26 M0 Check Script

Completed the M0 check script slice:

- Added `scripts/check-m0.sh` as the canonical local validation entry point.
- The script runs fixture validation, Swift package tests, Android unit tests and Kotlin compile, and iOS app build.
- Updated README local check instructions to match the commands used for current M0 verification.

### 2026-08-26 M0 Reset Validation Controls

Completed a validation reset slice for repeatable photo MVP testing:

- Added `clear` support to Android and iOS local sync result stores.
- Added `clear` support to iOS media download/import state stores.
- Added Android `Clear sync result` action for resetting manifest filtering input during M0 validation.
- Added iOS `Reset Local Sync State` action for clearing app-local transfer mappings and latest result JSON.
- Documented that reset controls do not delete imported iOS Photos library items.

Verified:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 iOS Pairing Session Persistence

Completed an iOS restart-resume slice for the photo MVP:

- Added `PairedDeviceSession` persistence for Android host, port, trusted device metadata, and M0 pairing token.
- iOS receive screen restores the last paired Android endpoint on launch.
- Pairing restore supports retrying an interrupted M0 transfer without immediately rescanning QR, as long as the Android server session token is still current.
- Documented that Android M0 server restarts still require a fresh QR scan or pasted payload because the token is regenerated.
- Added Swift coverage for paired session save, load, and clear behavior.

Verification target:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 iOS Media Range Resume Path

Completed a media retry foundation for interrupted photo transfers:

- iOS preserves partial local file metadata when a failed record is requeued.
- `MediaDownloader` sends `Range: bytes=<downloadedBytes>-` when persisted partial bytes are available.
- `206 Partial Content` responses are combined with the local prefix before checksum validation and final file write.
- iOS rejects missing or mismatched `Content-Range` metadata with `SS-MEDIA-003`.
- If Android ignores the range and returns `200 OK`, iOS treats the response as a full replacement to keep compatibility.
- Added Swift coverage for partial range resume and full-response fallback behavior.

Verification target:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 iOS Partial Response Validation

Completed a defensive validation slice for media resume:

- iOS now requires `206 Partial Content` responses to include a `Content-Range` whose start matches the persisted local offset.
- Partial responses with missing or mismatched `Content-Range` are rejected before bytes are combined.
- Added shared error code `SS-MEDIA-003` for invalid partial media responses.
- Added Swift coverage for missing and mismatched `Content-Range` metadata.

Verification target:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 iOS Partial Resume Visibility

Completed an iOS visibility slice for interrupted-transfer validation:

- Added a state-store query for resumable partial media records.
- iOS receive screen now shows `Partial` count for manifest items with persisted partial bytes and local file state.
- Partial records exclude completed full downloads and records without local file references.
- Added Swift coverage for resumable partial record filtering.

Verification target:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 Android Persisted Result Restore

Completed an Android validation visibility slice:

- Android now loads the persisted latest M0 sync result when the app opens.
- The latest sync result summary remains visible even before the local M0 server starts.
- `Clear sync result` is enabled whenever a persisted result exists, not only while the server is running.
- Stopping or failing to start the server restores the persisted result store instead of hiding existing validation state.

Verification target:

```sh
./scripts/check-m0.sh
```

### 2026-08-26 Android Media Range Validation

Completed the Android side of the media range contract:

- Android media routing now returns `416 Range Not Satisfiable` for invalid or unsatisfiable byte ranges.
- `416` responses include `Content-Range: bytes */<totalSize>` and shared error code `SS-REQ-416`.
- Android range parsing supports `bytes=<start>-`, `bytes=<start>-<end>`, and `bytes=-<suffixLength>`.
- Added Android router coverage for partial range metadata, suffix ranges, and unsatisfiable ranges.
- Updated the shared local API contract and device validation checklist.

Verification target:

```sh
./scripts/check-m0.sh
```
