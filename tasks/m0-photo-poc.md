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
- [ ] Bind router to a real Android embedded HTTP server.
- [ ] Connect media stream provider to real HTTP response bodies.

### A1. Project Setup

- [x] Create Android Studio project under `android/`.
- [x] Configure Kotlin.
- [x] Add app id, min SDK, target SDK.
- [x] Add local network and media permissions.

### A2. Device Identity

- [ ] Generate stable device id.
- [ ] Generate key pair placeholder for M0.
- [ ] Store identity locally.

### A3. Pairing Payload

- [ ] Resolve current local IP.
- [ ] Start local server on available port.
- [ ] Generate QR payload from `PairingPayloadFactory`.
- [ ] Render QR code in Android UI.

### A4. Media Scanner

- [ ] Implement `MediaScanner` using MediaStore.
- [ ] Query latest 100 images from DCIM/Camera.
- [ ] Map rows into `MediaAsset`.
- [ ] Add lazy SHA-256 calculation before transfer.

### A5. Local Server

- [ ] Implement `GET /v1/health`.
- [ ] Implement `GET /v1/manifest`.
- [ ] Implement `GET /v1/media/{assetId}`.
- [ ] Add range request support.
- [ ] Add basic error responses.

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
- [ ] Implement QR scanner UI.
- [ ] Implement media downloader.
- [ ] Implement PhotoKit importer.

### I1. Project Setup

- [x] Create Swift Package core under `ios/ShareSync`.
- [x] Create Xcode app project under `ios/`.
- [x] Configure SwiftUI app target.
- [x] Add camera permission for QR scanning.
- [x] Add Photos permission.
- [x] Add local network permission.

### I2. QR Pairing

- [ ] Implement QR scanner.
- [ ] Parse payload using `PairingPayloadParser`.
- [ ] Show paired Android device.

### I3. Manifest Client

- [ ] Use `ManifestClient` to fetch Android manifest.
- [ ] Show total photo count and total byte size.
- [ ] Store latest cursor.

### I4. Media Download

- [ ] Download photo files to app temp directory.
- [ ] Verify SHA-256 when available.
- [ ] Track per-asset download state.
- [ ] Resume or skip completed items after restart.

### I5. Photos Import

- [ ] Request Photos add permission.
- [ ] Create `ShareSync Backup` album.
- [ ] Import downloaded photos.
- [ ] Store Android asset id to iOS local identifier mapping.
- [ ] Prevent duplicate imports.

## Cross-Platform Tasks

- [x] Add shared sample pairing payload fixture.
- [x] Add shared sample manifest fixture.
- [x] Add lightweight fixture validation script.
- [ ] Validate generated manifest against `shared/schemas/manifest.schema.json`.
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

Next implementation slice:

- Bind Android `LocalSyncRouter` to an embedded HTTP server.
- Pipe `MediaStreamProvider` into `/v1/media/{assetId}` response bodies.
- Implement iOS media file downloader using the state store.
