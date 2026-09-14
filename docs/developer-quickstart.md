# Developer Quickstart

Status: M11 developer handoff guide.

This guide is for local development only. ShareSync M11 remains a photo-only Android-to-iPhone local sync MVP and should not be treated as an App Store or Google Play release candidate.

## Prerequisites

- macOS with Xcode installed for iOS development.
- Android Studio with the Android SDK installed for Android development.
- Java runtime compatible with the checked-in Gradle wrapper.
- Swift Package Manager, provided by Xcode command line tools.
- Python 3 for fixture and validation scripts.

## Open The Android Project

1. Open Android Studio.
2. Choose `Open`.
3. Select the repository `android/` directory.
4. Let Gradle sync finish.
5. Select the `app` run configuration.
6. Run on a physical Android phone for local-network/photo validation.

If Android Studio cannot find the SDK, create an untracked `android/local.properties` file:

```properties
sdk.dir=/path/to/Android/sdk
```

Do not commit `android/local.properties`.

## Open The iOS Project

1. Open Xcode.
2. Open `ios/ShareSync.xcodeproj`.
3. Select the `ShareSync` scheme.
4. Run on a physical iPhone for Photos, camera, and local-network validation.

Use the Swift package at the repository root for faster core tests:

```sh
swift test
```

## Targeted Checks

Run these from the repository root unless noted.

Fixture and protocol validation:

```sh
python3 scripts/validate-fixtures.py
python3 scripts/compare-sync-results.py shared/fixtures/sample-sync-result.json shared/fixtures/sample-sync-result.json
python3 scripts/validate-m0-results.py
```

iOS core tests:

```sh
swift test
```

iOS app build:

```sh
xcodebuild -project ios/ShareSync.xcodeproj \
  -scheme ShareSync \
  -destination 'generic/platform=iOS' \
  build
```

Android unit tests and Kotlin compile:

```sh
cd android
./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
```

QR-pinned HTTPS validation build:

```sh
cd android
./gradlew :app:assembleDebug -Psharesync.qrPinnedHttps=true
```

Only use this build when running the M4 QR-pinned HTTPS validation matrix. Default debug builds keep signed local HTTP active until physical-device HTTPS signoff is completed.

Full current main-axis check:

```sh
./scripts/check-m0.sh
```

Repository hygiene check:

```sh
bash scripts/check-repo-hygiene.sh
```

Release readiness gate:

```sh
bash scripts/check-release-readiness.sh --transport signed-http
bash scripts/check-release-readiness.sh --transport qr-pinned-https
```

The QR-pinned HTTPS gate is expected to fail until M4 physical-device validation is completed and recorded.

Beta handoff record:

```sh
bash scripts/generate-beta-handoff.sh --transport signed-http
```

Use `--output` only for an external handoff location. Do not commit generated handoff records or packaged app artifacts.

Beta preflight:

```sh
bash scripts/check-beta-preflight.sh --transport signed-http
bash scripts/check-beta-preflight.sh --transport signed-http --full
```

Use the default preflight for quick handoff checks and `--full` before sharing a source-code-backed beta build.

Support snapshot inspection:

```sh
python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-android.json
python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-ios.json --summary-only
```

Beta handoff record:

```sh
bash scripts/generate-beta-handoff.sh --transport signed-http
```

Use `--output` only for an external handoff location. Do not commit generated handoff records or packaged app artifacts.

## Before Committing

- Run `git diff --check`.
- Run `bash scripts/check-repo-hygiene.sh`.
- Run `bash scripts/check-release-readiness.sh --transport signed-http`.
- Run `./scripts/check-m0.sh` for main-axis changes.
- Confirm `git config user.name` and `git config user.email` are set to the intended author.
- Do not commit generated build output, local SDK paths, DerivedData, signing files, secrets, or local credentials.

## Real-Device Validation

Automated checks keep the code stable, but the full sync path still requires real devices because camera, Photos import, iCloud Photos behavior, Android MediaStore, local network permission, and app foreground/background behavior are OS-controlled.

Use these documents when real-device testing resumes:

- [M0 Device Validation Checklist](m0-device-validation.md)
- [M2 Device Validation Results](m2-device-validation-results.md)
- [M2 iOS Foreground/Background Checklist](m2-ios-foreground-background-checklist.md)
- [M5 Release Candidate Readiness](m5-release-candidate-readiness.md)
- [M6 Beta Package Readiness](m6-beta-package-readiness.md)
- [M7 Internal Beta Handoff](m7-internal-beta-handoff.md)
- [M8 Beta Preflight](m8-beta-preflight.md)
- [M9 Support Snapshot](m9-support-snapshot.md)
- [M10 Support Triage](m10-support-triage.md)
- [M11 Beta UX Readiness](m11-beta-ux-readiness.md)
