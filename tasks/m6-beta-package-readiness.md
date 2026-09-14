# M6 - Beta Package Readiness

Status: Complete after M5 release-candidate polish completion on 2026-09-14.

Goal: prepare the photo-only ShareSync build for a safer internal beta handoff without expanding the product scope, running real-device validation, or claiming store readiness.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
- No cloud relay or third-party storage.
- QR-pinned HTTPS remains opt-in and non-release-ready until M4 physical-device validation is recorded.
- Signed local HTTP remains allowed only for local-network developer/internal validation.

## Tracks

### M6.1 Platform Privacy And Network Surface

- [x] Narrow iOS ATS from arbitrary loads to local networking.
- [x] Add release-readiness checks that reject broad iOS arbitrary network loads.
- [x] Keep signed local HTTP release checks tied to `NSAllowsLocalNetworking`.

### M6.2 Build Identity And Support Traceability

- [x] Include iOS app version/build in copied diagnostics.
- [x] Document Android and iOS version alignment policy.
- [x] Add package-readiness notes for internal beta artifacts.

### M6.3 Store/Beta Copy Readiness

- [x] Review iOS permission strings for photo-only local sync claims.
- [x] Review Android permission and foreground-service wording for photo-only local sync claims.
- [x] Add a privacy copy checklist that explicitly excludes cloud relay and direct iCloud access.

### M6.4 Automated Gate

- [x] Keep `git diff --check`, repo hygiene, Swift tests, Android compile/tests, and full M0 gate green.

## Progress Log

### 2026-09-14 M6 Started

Started M6 with the lowest-risk privacy/package slice:

- Replaced broad iOS `NSAllowsArbitraryLoads` with `NSAllowsLocalNetworking`.
- Extended release readiness checks so broad iOS arbitrary network loads fail fast.
- Added iOS app version/build to copied diagnostics for support traceability.

### 2026-09-14 M6 Package Policy Added

Added the beta package readiness guide and strengthened automated checks:

- Documented Android/iOS version alignment for paired beta artifacts.
- Added release-readiness checks for Android and iOS version/build consistency.
- Reviewed permission wording and documented the photo-only privacy copy checklist.

### 2026-09-14 M6 Automated Gate Passed

Completed the M6 automated gate:

- `git diff --check` passed.
- `bash scripts/check-repo-hygiene.sh` passed.
- `bash scripts/check-release-readiness.sh --transport signed-http` passed.
- `swift test` passed.
- `xcodebuild -project ios/ShareSync.xcodeproj -scheme ShareSync -destination generic/platform=iOS build` passed.
- `./scripts/check-m0.sh` passed.
