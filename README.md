# ShareSync

Status: M0 implementation ready for real-device validation. Android can expose local photo endpoints, and iOS can pair, fetch, download, verify, and import Android photos into Photos on the same local network.

ShareSync is a native Android and iOS local sync app for a two-phone workflow:

- Android is the primary phone and sync controller.
- iPhone is the iCloud gateway.
- Data transfers locally between the two phones without a cloud relay.
- iPhone imports received photos into Photos, allowing iCloud Photos to back them up through Apple's normal Photos pipeline.

The project intentionally uses native implementation:

- Android: Kotlin
- iOS: Swift

## Current Stage

The repository is focused on `M0 - Android to iOS Photo PoC`.

The current codebase contains:

- Product and engineering documents.
- Shared protocol schemas.
- An Android Studio project under `android/`.
- An Xcode iOS app project at `ios/ShareSync.xcodeproj`.
- A Swift Package core at the repository root for fast iOS core tests.
- An embedded Android local HTTP server for M0 health, manifest, and media endpoints.
- Android QR pairing payload UI with stable local device identity and actual bound port.
- Android can copy the current health endpoint for same-network or hotspot validation.
- iOS QR scanner and manual pairing fallback.
- M0 protected endpoints require the QR pairing token header for manifest, media, and sync result requests.
- iOS receive screen that fetches the Android photo manifest, downloads one or more photos, verifies checksums when available, and imports into the `ShareSync Backup` Photos album.
- iOS local-network requests use explicit timeouts: short for health/manifest/result posts and longer for photo media transfers.
- iOS receive screen can download the next item, a small batch, or all remaining manifest items for M0 device validation.
- iOS receive screen shows a manifest transfer status for ready, retry, complete, or no-photo validation.
- iOS receive screen shows live batch progress, downloaded count, failed count, and current file during foreground transfer.
- iOS receive screen shows resumable partial photo count for interrupted-transfer validation.
- iOS media download can issue `Range` requests from a persisted partial offset and combine `206 Partial Content` responses.
- iOS validates `206 Partial Content` `Content-Range` metadata before combining partial media bytes.
- iOS receive screen can stop an active foreground transfer while keeping completed items retry-safe.
- iOS pauses active foreground transfers when the app leaves the foreground, keeping completed items retry-safe.
- iOS local download/import state, duplicate prevention, restart resume, and deleted-photo reconciliation.
- iOS latest sync result JSON persistence for M0 validation.
- iOS to Android sync result return path over the local M0 server.
- Android latest sync result persistence and M0 screen summary.
- Android restores the latest persisted sync result on app launch for validation.
- Android M0 screen shows pending manifest photo count, manifest transfer status, and latest failed sync result code.
- Android can copy the latest sync result JSON for real-device validation records.
- Android manifest filtering for media already reported as synced or skipped.
- Android merged sync result history across M0 batches.
- iOS paired Android host, port, device metadata, and M0 pairing token persistence across app restarts.
- iOS clear-pairing control for refreshing stale Android M0 endpoint/token state without deleting the app.

M0 validates the riskiest path:

```text
Android MediaStore photos -> local manifest/server -> iOS client -> Photos import
```

## Repository Layout

```text
android/
  app/src/main/java/com/sharesync/android/
    pairing/
    scanner/
    transfer/
    sync/
    security/
    persistence/

ios/
  ShareSync/
    Pairing/
    Transfer/
    ImporterPhotos/
    Sync/
    Security/
    Persistence/

shared/
  protocol/
  schemas/

docs/
  product-development-plan.md
  implementation-spec.md
  m0-device-validation.md

tasks/
  m0-photo-poc.md
```

## Documents

- [Product Development Plan](docs/product-development-plan.md)
- [Implementation Spec](docs/implementation-spec.md)
- [UI/UX Design Guidelines](docs/ui-design-guidelines.md)
- [Local API Contract](shared/protocol/api-contract.md)
- [M0 Device Validation Checklist](docs/m0-device-validation.md)
- [M0 Validation Results](docs/m0-validation-results.md)
- [M0 Photo PoC](tasks/m0-photo-poc.md)

## M0 Rules

M0 may use plain local HTTP to reduce setup cost. MVP must upgrade to local HTTPS and signed requests.

M0 includes only:

- QR pairing payload structure
- pairing-token header enforcement for protected local endpoints
- QR pairing scanner/manual fallback
- Android photo manifest
- Android photo download endpoint
- lazy media checksum header for full downloads
- iOS manifest fetch
- iOS photo download
- iOS Photos import
- local-network timeout tuning
- duplicate prevention
- interrupted sync resume
- partial media range retry foundation
- partial response range validation
- resumable partial count visibility
- all-remaining foreground batch transfer for device validation
- foreground batch progress visibility
- foreground transfer stop and retry
- foreground transfer pause on iOS backgrounding
- app-local imported photo reconciliation
- latest sync result JSON persistence
- local sync result return to Android
- Android latest sync result display for validation
- Android latest sync result restore while server is stopped
- Android endpoint copy action for local connectivity validation
- Android manifest excludes completed media from latest sync result
- Android latest sync result merges multiple reported batches

M0 excludes:

- Contacts
- Files
- BLE
- Background scheduling hardening
- App Store-ready privacy copy
- Full request signing

## Development Notes

- Keep shared JSON field names aligned with `shared/schemas`.
- Treat Android as the source/controller for MVP.
- Treat iOS as the receiver/iCloud gateway for MVP.
- Do not add external cloud relay logic.
- Do not add Apple ID or iCloud password handling.
- iOS foreground transfer is guarded: the screen stays awake while active, and leaving the foreground pauses the transfer for retry.
- Deleting the iOS app deletes its local sync mapping and can make previously imported Android photos eligible again.
- Use the M0 reset controls only for validation. They clear ShareSync local state, not imported Photos library items.
- iOS restores the last paired Android endpoint on app launch. If Android restarts its M0 server, scan the new QR code to refresh the short-lived pairing token.

## Local Checks

Run the full M0 check suite from the repository root:

```sh
./scripts/check-m0.sh
```

Run checks individually when isolating a failure:

```sh
python3 scripts/validate-fixtures.py
swift test

cd android
./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
cd ..

xcodebuild -project ios/ShareSync.xcodeproj \
  -scheme ShareSync \
  -destination 'generic/platform=iOS' \
  build
```

## M0 Manual Test

Android:

- Open `android/` in Android Studio.
- Run the `app` configuration on a physical Android phone.
- Grant photos permission.
- Tap `Start M0 server`.
- Confirm the screen shows a manual endpoint and QR code.
- Use `Copy endpoint` if you want to test the health URL from iPhone Safari.
- If port `48291` is busy, Android falls back to an available port and displays that actual port.

iOS:

- Open `ios/ShareSync.xcodeproj` in Xcode.
- Run the `ShareSync` scheme on an iPhone connected to the same network.
- Scan the Android QR code, or paste the manual pairing payload.
- If ShareSync was previously paired, confirm the Android IP and port are restored on launch.
- Use `Clear Pairing` before scanning a fresh Android QR code if Android restarted and generated a new M0 token.
- Tap `Fetch Manifest`.
- Tap `Download Next Item` or `Download 5 Items`.
- Tap `Download Remaining` for the 100-item foreground transfer validation.
- Use `Reset Local Sync State` only when you need to rerun validation from a clean iOS ShareSync state.
- Open Photos and confirm imported photos appear in the `ShareSync Backup` album.

Resetting test state:

- Android `Clear sync result` removes the locally stored iOS result report so Android can rebuild manifest filtering from future reports.
- Android `Copy sync result` copies the latest persisted iOS result JSON for validation notes or issue reports.
- iOS `Reset Local Sync State` removes ShareSync download/import mappings and latest result JSON. Photos already imported into the `ShareSync Backup` album remain in Photos.
- iOS `Clear Pairing` removes only the saved Android endpoint, device metadata, pairing token, and pasted payload. It does not clear download/import mappings.

Use [docs/m0-device-validation.md](docs/m0-device-validation.md) as the real-device acceptance checklist, and record pass/fail evidence in [docs/m0-validation-results.md](docs/m0-validation-results.md), before calling M0 complete.

If Gradle cannot find the Android SDK, create an untracked `android/local.properties`:

```properties
sdk.dir=/Users/mingyao/Library/Android/sdk
```

## Opening Projects

Android:

- Open the `android/` directory in Android Studio.
- Select the `app` run configuration.

iOS:

- Open `ios/ShareSync.xcodeproj` in Xcode.
- Select the `ShareSync` scheme.

Swift Package core:

- Open `Package.swift` in Xcode, or run `swift test`.

## Current Limitations

- iOS background syncing is not implemented; keep the app open for M0.
- Transfers are local-network only and currently use plain local HTTP.
- Range retry is implemented for persisted partial download state; M0 still runs as a foreground transfer on iOS.
- Duplicate prevention is based on app-local Android asset/import mapping.
- Deleting the iOS app deletes the local mapping; Photos contents remain, but ShareSync may treat Android items as new.
- iCloud backup is indirect: ShareSync imports into iOS Photos, then iCloud Photos handles backup according to the user's iOS settings.

## Rights

All rights reserved unless a separate LICENSE file is added later.
