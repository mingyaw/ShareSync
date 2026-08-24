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
- [x] Add MediaStore-backed media lookup provider.
- [x] Add media stream provider for content URIs.
- [x] Bind router to a real Android embedded HTTP server.
- [x] Connect media stream provider to real HTTP response bodies.
- [x] Add app-level M0 sync component factory.
- [x] Add Android UI controls to request media permission and start/stop server.
- [x] Show Android local IP/port for manual testing.

### A1. Project Setup

- [x] Create Android Studio project under `android/`.
- [x] Configure Kotlin.
- [x] Add app id, min SDK, target SDK.
- [x] Add local network and media permissions.

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
- [x] Query latest 100 images/videos from MediaStore.
- [x] Map rows into `MediaAsset`.
- [x] Add lazy SHA-256 calculation before transfer.

### A5. Local Server

- [x] Implement `GET /v1/health`.
- [x] Implement `GET /v1/manifest`.
- [x] Implement `GET /v1/media/{assetId}`.
- [x] Add range request support.
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

### I1. Project Setup

- [x] Create Swift Package core under `ios/ShareSync`.
- [x] Create Xcode app project under `ios/`.
- [x] Configure SwiftUI app target.
- [x] Add camera permission for QR scanning.
- [x] Add Photos permission.
- [x] Add local network permission.

### I2. QR Pairing

- [x] Implement QR scanner.
- [x] Parse payload using `PairingPayloadParser`.
- [x] Show paired Android device.

### I3. Manifest Client

- [x] Use `ManifestClient` to fetch Android manifest.
- [x] Show total photo count and total byte size.
- [x] Show latest cursor in the M0 receive screen.

### I4. Media Download

- [x] Download one photo/video file to app temp directory for validation.
- [x] Verify SHA-256 when available.
- [x] Track per-asset download state.
- [x] Expand UI action from single-item validation to batch download.
- [x] Resume or skip completed items after restart.

### I5. Photos Import

- [x] Request Photos permission.
- [x] Create `ShareSync Backup` album.
- [x] Import one downloaded photo/video for validation.
- [x] Store Android asset id to iOS local identifier mapping.
- [x] Prevent duplicate imports.

## Cross-Platform Tasks

- [x] Add shared sample pairing payload fixture.
- [x] Add shared sample manifest fixture.
- [x] Add lightweight fixture validation script.
- [x] Validate generated manifest against `shared/schemas/manifest.schema.json`.
- [x] Keep fixture date encoding ISO-8601.
- [x] Keep fixture enum values lowercase.
- [x] Align item status values with `sync-result.schema.json`.

## Test Matrix

- [ ] iPhone foreground, Android foreground.
- [ ] iPhone lock screen during download.
- [ ] Android app backgrounded during transfer.
- [ ] Same Wi-Fi.
- [ ] Android hotspot.
- [ ] Transfer interrupted midway.
- [ ] Repeat sync.
- [ ] No Photos permission.
- [ ] iPhone storage low.

## Manual M0 Device Validation

Run the full checklist in `docs/m0-device-validation.md` before calling M0 complete.

## Out of Scope for M0

- Contacts.
- Files.
- BLE discovery.
- Background URLSession tuning.
- Full HTTPS certificate handling.
- Full request signing.
- App Store release.

## Progress Log

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

- Android `MediaStoreMediaScanner` for recent photo/video metadata.
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

- Runtime media permission request.
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

- Android media permission request flow.
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
1. Grant media permission.
2. Tap Start M0 server.
3. Open the displayed http://<android-ip>:48291/v1/health endpoint from another device on the same Wi-Fi.
4. Test http://<android-ip>:48291/v1/manifest after media permission is granted.
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
- SwiftUI receive screen action to download only the first manifest media item.
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
- Single downloaded photo/video import into the backup album.
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
