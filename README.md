# ShareSync

Status: M0 photo PoC through M26 accessibility and adaptive layout are complete for the photo-only MVP source-code track.

ShareSync is a native Android and iOS local sync app for a two-phone workflow:

- Android is the primary phone and sync controller.
- iPhone is the iCloud gateway.
- Data transfers locally between the two phones without a cloud relay.
- iPhone imports received photos into Photos, allowing iCloud Photos to back them up through Apple's normal Photos pipeline.

The project intentionally uses native implementation:

- Android: Kotlin
- iOS: Swift

## Current Stage

The completed baseline is `M0 - Android to iOS Photo PoC` through `M26 - Accessibility And Adaptive Layout`. The photo-only MVP now has repeatable validation, package readiness, handoff notes, beta preflight automation, redacted JSON diagnostics, local support snapshot triage, product-focused next-step guidance, tested readiness presenter state, strictly validated next-step support snapshot evidence, support snapshot inspector regression tests, platform-aware support snapshot fixture validation, beta handoff quality notes, main-axis check boundaries, error recovery alignment, a source-code static beta freeze checkpoint, a first-pass product UI/UX flow, lightweight native visual theme tokens, and adaptive accessibility behavior for compact screens and larger system text.

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
- Protected photo endpoints require signed local requests after QR pairing.
- iOS receive screen that fetches the Android photo manifest, downloads one or more photos, verifies checksums when available, and imports into the `ShareSync Backup` Photos album.
- iOS local-network requests use explicit timeouts: short for health/manifest/result posts and longer for photo media transfers.
- iOS receive screen can download the next item, a small batch, or all remaining manifest items for M0 device validation.
- iOS receive screen shows a concise phase status for pairing, fetch, transfer, retry, and completion validation.
- iOS receive screen shows a product-focused next-step instruction derived from the primary readiness action.
- iOS readiness tests cover the next-step presenter state used by the receive screen.
- iOS receive screen shows a manifest transfer status for ready, retry, complete, or no-photo validation.
- iOS receive screen shows live batch progress, downloaded count, failed count, and current file during foreground transfer.
- iOS receive screen shows resumable partial photo count for interrupted-transfer validation.
- iOS media download can issue `Range` requests from a persisted partial offset and combine `206 Partial Content` responses.
- iOS validates `206 Partial Content` `Content-Range` metadata before combining partial media bytes.
- iOS receive screen can stop an active foreground transfer while keeping completed items retry-safe.
- iOS pauses active foreground transfers when the app leaves the foreground, keeping completed items retry-safe.
- iOS local download/import state, duplicate prevention, restart resume, and deleted-photo reconciliation.
- iOS latest sync result JSON persistence, restore, and copy action for M0 validation.
- iOS to Android sync result return path over the local M0 server, with visible posted/failed return status.
- Android latest sync result persistence and M0 screen summary.
- Android restores the latest persisted sync result on app launch for validation.
- Android starts a foreground data-sync service while the M0 local server is running.
- Android can reconnect the M0 screen to an already running in-process server session after Activity recreation.
- Android M0 screen shows a concise phase status for permission, server start, pairing, retry, and completion validation.
- Android M0 screen shows a product-focused next-step instruction derived from the runtime readiness state.
- Android runtime tests cover the next-step presenter state used by the M0 screen.
- Android M0 screen shows pending manifest photo count, manifest transfer status, latest local request activity, and latest failed sync result code.
- Android can copy the latest sync result JSON for real-device validation records.
- Android manifest filtering for media already reported as synced or skipped.
- Android merged sync result history across M0 batches.
- iOS paired Android host, port, device metadata, and M0 pairing token persistence across app restarts.
- iOS clear-pairing control for refreshing stale Android M0 endpoint/token state without deleting the app.
- Android and iOS copied diagnostics use a shared redacted support snapshot JSON format.
- Android and iOS support snapshots include stable next-step action codes for beta triage.
- The support snapshot inspector rejects invalid platform-specific next-step action codes.
- Support snapshot inspector regression tests cover valid fixtures, missing next-step data, cross-platform next-step data, and sensitive marker leakage.
- Fixture validation rejects support snapshot examples whose next-step action does not belong to the example platform.
- Beta handoff output includes support snapshot summaries and explicit deferred validation notes.
- Error recovery documentation is aligned with support snapshot next-step evidence.
- Android and iOS primary UI copy now emphasizes photo status, pairing, syncing, and support instead of protocol terminology.
- Android and iOS screens now use lightweight visual theme tokens for status colors, surfaces, dividers, and panel polish.
- Android and iOS primary screens now expose section headings and status semantics to assistive technologies.
- iOS summary metrics, status rows, and paired actions adapt from horizontal to vertical layouts when content or system text requires more room.
- Support snapshots can be validated and summarized locally for internal beta triage.

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
- [Developer Quickstart](docs/developer-quickstart.md)
- [M1 Release Readiness](docs/m1-release-readiness.md)
- [M3 Pre-Release Readiness](docs/m3-release-readiness.md)
- [M5 Release Candidate Readiness](docs/m5-release-candidate-readiness.md)
- [M6 Beta Package Readiness](docs/m6-beta-package-readiness.md)
- [M7 Internal Beta Handoff](docs/m7-internal-beta-handoff.md)
- [M8 Beta Preflight](docs/m8-beta-preflight.md)
- [M9 Support Snapshot](docs/m9-support-snapshot.md)
- [M10 Support Triage](docs/m10-support-triage.md)
- [M11 Beta UX Readiness](docs/m11-beta-ux-readiness.md)
- [M12 Readiness Presenter Hardening](docs/m12-readiness-presenter-hardening.md)
- [M13 Support Next-Step Snapshot](docs/m13-support-next-step-snapshot.md)
- [M14 Support Snapshot Strict Next-Step Validation](docs/m14-support-snapshot-strict-next-step.md)
- [M15 Support Snapshot Inspector Tests](docs/m15-support-snapshot-inspector-tests.md)
- [M16 Platform-Specific Fixture Validation](docs/m16-platform-specific-fixture-validation.md)
- [M17 Beta Handoff Quality](docs/m17-beta-handoff-quality.md)
- [M18 Main-Axis Check Boundaries](docs/m18-main-axis-check-boundaries.md)
- [M19 Error Recovery Alignment](docs/m19-error-recovery-alignment.md)
- [M20 Static Beta Freeze](docs/m20-static-beta-freeze.md)
- [M21 UI Information Architecture](docs/m21-ui-information-architecture.md)
- [M22 UI Visual Polish](docs/m22-ui-visual-polish.md)
- [M23 UX Copy And Flow](docs/m23-ux-copy-flow.md)
- [M24 Visual Design System](docs/m24-visual-design-system.md)
- [M25 Screen Polish](docs/m25-screen-polish.md)
- [M26 Accessibility And Adaptive Layout](docs/m26-accessibility-adaptive-layout.md)
- [UI/UX Design Guidelines](docs/ui-design-guidelines.md)
- [Error Recovery Matrix](docs/error-recovery-matrix.md)
- [Sync History Summary](docs/sync-history-summary.md)
- [Persistence And Reset Semantics](docs/persistence-reset-semantics.md)
- [Local HTTPS Threat Model](docs/local-https-threat-model.md)
- [Local Security Implementation Spec](docs/local-security-implementation-spec.md)
- [Local API Contract](shared/protocol/api-contract.md)
- [M0 Device Validation Checklist](docs/m0-device-validation.md)
- [M0 Validation Results](docs/m0-validation-results.md)
- [M2 Device Validation Results](docs/m2-device-validation-results.md)
- [M2 iOS Foreground/Background Checklist](docs/m2-ios-foreground-background-checklist.md)
- [M0 Photo PoC](tasks/m0-photo-poc.md)
- [M1 Photo MVP Hardening](tasks/m1-photo-mvp.md)
- [M2 Photo Product Reliability](tasks/m2-photo-product-reliability.md)
- [M3 Pre-Release Product Hardening](tasks/m3-pre-release-product-hardening.md)
- [M4 QR-Pinned HTTPS](tasks/m4-qr-pinned-https.md)
- [M5 Release Candidate Polish](tasks/m5-release-candidate-polish.md)
- [M6 Beta Package Readiness](tasks/m6-beta-package-readiness.md)
- [M7 Internal Beta Handoff](tasks/m7-internal-beta-handoff.md)
- [M8 Beta Preflight](tasks/m8-beta-preflight.md)
- [M9 Support Snapshot](tasks/m9-support-snapshot.md)
- [M10 Support Triage](tasks/m10-support-triage.md)
- [M11 Beta UX Readiness](tasks/m11-beta-ux-readiness.md)
- [M12 Readiness Presenter Hardening](tasks/m12-readiness-presenter-hardening.md)
- [M13 Support Next-Step Snapshot](tasks/m13-support-next-step-snapshot.md)
- [M14 Support Snapshot Strict Next-Step Validation](tasks/m14-support-snapshot-strict-next-step.md)
- [M15 Support Snapshot Inspector Tests](tasks/m15-support-snapshot-inspector-tests.md)
- [M16 Platform-Specific Fixture Validation](tasks/m16-platform-specific-fixture-validation.md)
- [M17 Beta Handoff Quality](tasks/m17-beta-handoff-quality.md)
- [M18 Main-Axis Check Boundaries](tasks/m18-main-axis-check-boundaries.md)
- [M19 Error Recovery Alignment](tasks/m19-error-recovery-alignment.md)
- [M20 Static Beta Freeze](tasks/m20-static-beta-freeze.md)
- [M21 UI Information Architecture](tasks/m21-ui-information-architecture.md)
- [M22 UI Visual Polish](tasks/m22-ui-visual-polish.md)
- [M23 UX Copy And Flow](tasks/m23-ux-copy-flow.md)
- [M24 Visual Design System](tasks/m24-visual-design-system.md)
- [M25 Screen Polish](tasks/m25-screen-polish.md)
- [M26 Accessibility And Adaptive Layout](tasks/m26-accessibility-adaptive-layout.md)

## M0 Rules

M0 used plain local HTTP to reduce setup cost. M1 keeps transfer on the local network and requires signed requests for protected endpoints; local HTTPS is tracked as pre-release hardening before a broader beta or store-facing build.

M0 includes only:

- QR pairing payload structure
- signed request enforcement for protected local endpoints
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

Run repo hygiene checks before committing:

```sh
bash scripts/check-repo-hygiene.sh
```

Run checks individually when isolating a failure:

```sh
python3 scripts/validate-fixtures.py
python3 scripts/compare-sync-results.py ios-result.json android-result.json
python3 scripts/validate-m0-results.py
bash scripts/test-support-snapshot-inspector.sh
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
- Grant M0 permissions, including photos and Android notification permission when prompted.
- Tap `Start M0 server`.
- Confirm the screen shows a manual endpoint and QR code.
- Use `Copy endpoint` if you want to test the health URL from iPhone Safari.
- If port `48291` is busy, Android falls back to an available port and displays that actual port.

iOS:

- Open `ios/ShareSync.xcodeproj` in Xcode.
- Run the `ShareSync` scheme on an iPhone connected to the same network.
- Scan the Android QR code, or paste the manual pairing payload.
- If ShareSync was previously paired, confirm the Android IP and port are restored on launch.
- Use `Clear Pairing` before scanning a fresh Android QR code if Android restarted and generated a new pairing secret.
- Tap `Fetch Manifest`.
- Tap `Download Next Item` or `Download 5 Items`.
- Tap `Download Remaining` for the 100-item foreground transfer validation.
- Use `Copy Sync Result` to copy the latest iOS-generated result JSON after a manifest fetch or transfer.
- Use `Reset Local Sync State` only when you need to rerun validation from a clean iOS ShareSync state.
- Open Photos and confirm imported photos appear in the `ShareSync Backup` album.

Resetting test state:

- Android `Clear sync result` removes the locally stored iOS result report so Android can rebuild manifest filtering from future reports.
- Android `Copy sync result` copies the latest persisted iOS result JSON for validation notes or issue reports.
- iOS `Copy Sync Result` copies the latest locally generated result JSON for comparison with Android.
- iOS `Reset Local Sync State` removes ShareSync download/import mappings and latest result JSON. Photos already imported into the `ShareSync Backup` album remain in Photos.
- iOS `Clear Pairing` removes only the saved Android endpoint, device metadata, pairing token, and pasted payload. It does not clear download/import mappings or the latest sync result evidence.

M0 real-device validation was completed by user report on 2026-09-02. Use [docs/m0-device-validation.md](docs/m0-device-validation.md) to rerun the acceptance checklist, and keep pass/fail evidence in [docs/m0-validation-results.md](docs/m0-validation-results.md).

If Gradle cannot find the Android SDK, create an untracked `android/local.properties`:

```properties
sdk.dir=/path/to/Android/sdk
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
- Transfers are local-network only and currently use signed local HTTP; local HTTPS is a pre-release hardening branch.
- Range retry is implemented for persisted partial download state; M0 still runs as a foreground transfer on iOS.
- Duplicate prevention is based on app-local Android asset/import mapping.
- Deleting the iOS app deletes the local mapping; Photos contents remain, but ShareSync may treat Android items as new.
- iCloud backup is indirect: ShareSync imports into iOS Photos, then iCloud Photos handles backup according to the user's iOS settings.

## Rights

All rights reserved unless a separate LICENSE file is added later.
