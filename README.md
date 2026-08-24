# ShareSync

Status: M0 implementation ready for real-device validation. Android can expose local media endpoints, and iOS can pair, fetch, download, verify, and import Android media into Photos on the same local network.

ShareSync is a native Android and iOS local sync app for a two-phone workflow:

- Android is the primary phone and sync controller.
- iPhone is the iCloud gateway.
- Data transfers locally between the two phones without a cloud relay.
- iPhone imports received photos and videos into Photos, allowing iCloud Photos to back them up through Apple's normal Photos pipeline.

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
- iOS QR scanner and manual pairing fallback.
- iOS receive screen that fetches the Android manifest, downloads one or more items, verifies checksums when available, and imports into the `ShareSync Backup` Photos album.
- iOS local download/import state, duplicate prevention, restart resume, and deleted-photo reconciliation.
- iOS latest sync result JSON persistence for M0 validation.
- iOS to Android sync result return path over the local M0 server.
- Android latest sync result persistence and M0 screen summary.
- Android manifest filtering for media already reported as synced or skipped.
- Android merged sync result history across M0 batches.

M0 validates the riskiest path:

```text
Android MediaStore -> local manifest/server -> iOS client -> Photos import
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
- [M0 Photo PoC](tasks/m0-photo-poc.md)

## M0 Rules

M0 may use plain local HTTP to reduce setup cost. MVP must upgrade to local HTTPS and signed requests.

M0 includes only:

- QR pairing payload structure
- QR pairing scanner/manual fallback
- Android media manifest
- Android media download endpoint
- lazy media checksum header for full downloads
- iOS manifest fetch
- iOS media download
- iOS Photos import
- duplicate prevention
- interrupted sync resume
- app-local imported photo reconciliation
- latest sync result JSON persistence
- local sync result return to Android
- Android latest sync result display for validation
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
- iOS must remain foreground during current M0 validation.
- Deleting the iOS app deletes its local sync mapping and can make previously imported Android media eligible again.

## Local Checks

Run lightweight shared/core checks from the repository root:

```sh
python3 scripts/validate-fixtures.py
swift test
```

Run native project checks:

```sh
cd android
./gradlew :app:compileDebugKotlin
cd ..

xcodebuild -project ios/ShareSync.xcodeproj \
  -scheme ShareSync \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## M0 Manual Test

Android:

- Open `android/` in Android Studio.
- Run the `app` configuration on a physical Android phone.
- Grant media permission.
- Tap `Start M0 server`.
- Confirm the screen shows a manual endpoint and QR code.
- If port `48291` is busy, Android falls back to an available port and displays that actual port.

iOS:

- Open `ios/ShareSync.xcodeproj` in Xcode.
- Run the `ShareSync` scheme on an iPhone connected to the same network.
- Scan the Android QR code, or paste the manual pairing payload.
- Tap `Fetch Manifest`.
- Tap `Download Next Item` or `Download 5 Items`.
- Open Photos and confirm imported media appears in the `ShareSync Backup` album.

Use [docs/m0-device-validation.md](docs/m0-device-validation.md) as the real-device acceptance checklist before calling M0 complete.

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
- Duplicate prevention is based on app-local Android asset/import mapping.
- Deleting the iOS app deletes the local mapping; Photos contents remain, but ShareSync may treat Android items as new.
- iCloud backup is indirect: ShareSync imports into iOS Photos, then iCloud Photos handles backup according to the user's iOS settings.

## Rights

All rights reserved unless a separate LICENSE file is added later.
