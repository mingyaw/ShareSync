# M7 Internal Beta Handoff

Status: Active internal beta handoff guide for the photo-only MVP.

M7 makes package handoff repeatable without committing app binaries, signing material, generated handoff records, or local build output.

## Package Scope

Internal beta artifacts remain limited to:

- Android app build for local photo source/server behavior.
- iOS app build for local pairing, photo download, and Photos import behavior.
- Signed local HTTP transport unless QR-pinned HTTPS validation has been explicitly completed.

The beta package does not claim support for videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, cloud relay, direct iCloud access, Apple ID access, or iCloud Drive access.

## Android Package Notes

Build from the repository root or `android/` directory using the checked-in Gradle wrapper.

Debug APK for internal local validation:

```sh
cd android
./gradlew :app:assembleDebug
```

QR-pinned HTTPS validation APK:

```sh
cd android
./gradlew :app:assembleDebug -Psharesync.qrPinnedHttps=true
```

Only use the QR-pinned HTTPS build for M4 security validation until the physical-device matrix is completed.

Keep APK/AAB files outside the repository. Do not commit generated package files, local signing keys, keystores, Play upload credentials, or local SDK paths.

## iOS Package Notes

Open `ios/ShareSync.xcodeproj` in Xcode for signing, archive, and export workflows.

Recommended command-line compile check:

```sh
xcodebuild -project ios/ShareSync.xcodeproj \
  -scheme ShareSync \
  -destination 'generic/platform=iOS' \
  build
```

Use Xcode-managed signing or an external signing workflow outside Git. Do not commit `.ipa`, `.xcarchive`, `.dSYM`, provisioning profiles, certificates, export option files with private team data, or DerivedData.

## Handoff Record

Generate a handoff record after building external artifacts:

```sh
bash scripts/generate-beta-handoff.sh \
  --transport signed-http \
  --artifact /path/to/ShareSync-android.apk \
  --artifact /path/to/ShareSync-ios.ipa \
  --output /path/to/ShareSync-beta-handoff.md
```

The script records:

- Commit SHA and branch.
- Working tree clean/dirty status.
- Android version name/code.
- iOS marketing version/build.
- Transport mode.
- Release-readiness gate result.
- Artifact file size and SHA-256 checksum when artifact paths are provided.
- Explicit product scope boundaries.

Generate the final handoff record from a clean working tree after committing source changes.

## Package Checklist

Before sharing an internal beta package:

- Android `versionName` matches iOS `MARKETING_VERSION`.
- Android `versionCode` matches iOS `CURRENT_PROJECT_VERSION`.
- `bash scripts/check-release-readiness.sh --transport signed-http` passes.
- `bash scripts/check-repo-hygiene.sh` passes.
- `./scripts/check-m0.sh` passes when source code changed.
- Handoff record exists outside Git.
- Artifact checksums are recorded.
- Real-device validation status is recorded as completed or explicitly deferred.
- Known limitations are written in the handoff notes.
