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

### A1. Project Setup

- [ ] Create Android Studio project under `android/`.
- [ ] Configure Kotlin.
- [ ] Add app id, min SDK, target SDK.
- [ ] Add local network and media permissions.

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

### I1. Project Setup

- [ ] Create Xcode project under `ios/`.
- [ ] Configure SwiftUI app target.
- [ ] Add camera permission for QR scanning.
- [ ] Add Photos permission.
- [ ] Add local network permission.

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

- [ ] Validate generated manifest against `shared/schemas/manifest.schema.json`.
- [ ] Keep date encoding ISO-8601.
- [ ] Keep enum values lowercase.
- [ ] Align item status values with `sync-result.schema.json`.

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

