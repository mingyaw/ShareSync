# ShareSync

Status: M0 implementation. Android can expose local media endpoints, and iOS can manually fetch and download media on the same local network.

ShareSync is a native Android and iOS local sync app for a two-phone workflow:

- Android is the primary phone and sync controller.
- iPhone is the iCloud gateway.
- Data transfers locally between the two phones.
- iPhone imports received data into Photos, Contacts, and the app's iCloud Documents container.

The project intentionally uses native implementation:

- Android: Kotlin
- iOS: Swift

## Current Stage

The repository is prepared for `M0 - Android to iOS Photo PoC`.

The current codebase contains:

- Product and engineering documents.
- Shared protocol schemas.
- An Android Studio project under `android/`.
- An Xcode iOS app project at `ios/ShareSync.xcodeproj`.
- A Swift Package core at the repository root for fast iOS core tests.
- An embedded Android local HTTP server for M0 health, manifest, and media endpoints.
- An iOS receive screen that can manually fetch the Android manifest and download media files to app temp storage.

It does not yet contain:

- QR pairing UI.
- A complete iOS Photos import flow.

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

tasks/
  m0-photo-poc.md
```

## Documents

- [Product Development Plan](docs/product-development-plan.md)
- [Implementation Spec](docs/implementation-spec.md)
- [UI/UX Design Guidelines](docs/ui-design-guidelines.md)
- [Local API Contract](shared/protocol/api-contract.md)
- [M0 Photo PoC](tasks/m0-photo-poc.md)

## M0 Rules

M0 may use plain local HTTP to reduce setup cost. MVP must upgrade to local HTTPS and signed requests.

M0 includes only:

- QR pairing payload structure
- Android media manifest
- Android media download endpoint
- iOS manifest fetch
- iOS media download
- iOS Photos import
- duplicate prevention
- interrupted sync resume

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

## Local Checks

Run lightweight shared/core checks:

```sh
python3 scripts/validate-fixtures.py
swift test
```

Run native project checks:

```sh
cd android
./gradlew :app:assembleDebug

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
- Tap `Start Server`.
- Note the displayed `http://<android-ip>:48291/v1/health` endpoint.

iOS:

- Open `ios/ShareSync.xcodeproj` in Xcode.
- Run the `ShareSync` scheme on iPhone or Simulator connected to the same network.
- Enter the Android IP and port `48291`.
- Tap `Fetch Manifest`.
- Tap `Download Media` to save manifest media into the app temp download directory.

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

## Rights

All rights reserved unless a separate LICENSE file is added later.
