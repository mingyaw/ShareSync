# M1 Photo MVP Release Readiness

Status: active development checklist for the photo-only Android to iOS MVP.

M1 is not a public store release. It is the first product-shaped MVP for a single user with one Android phone and one iPhone on the same local network. The iPhone imports Android photos into iOS Photos, and iCloud Photos handles backup only after the import succeeds.

## Privacy Copy

Use this wording direction in app screens, permission rationale, README, and store-prep material:

- ShareSync transfers photos directly between the user's paired Android phone and iPhone on the local network.
- ShareSync does not upload photos to a developer server or third-party cloud relay.
- The Android phone reads local photo metadata and serves selected photo bytes only to the paired iPhone.
- The iPhone downloads photos from the paired Android phone and imports them into iOS Photos.
- iCloud backup is handled by iCloud Photos after import, according to the user's iOS and iCloud settings.
- Resetting ShareSync clears local pairing, transfer state, sync results, and event history, but it does not delete photos already imported into iOS Photos.
- Deleting the iOS app removes ShareSync's local import mapping. Imported Photos library items remain, but a future reinstall may treat Android photos as new unless durable cross-install identity is added later.
- ShareSync does not ask for Apple ID, iCloud password, Google account, or cloud-storage credentials.

## Build Variant Notes

Android debug:

- Open `android/` in Android Studio.
- Run the `app` configuration on a physical Android device.
- Use debug builds for current M1 validation.
- The local server advertises and serves only while the Android app/service is active.
- The default protected endpoints require signed local requests.

iOS debug:

- Open `ios/ShareSync.xcodeproj` in Xcode.
- Select the `ShareSync` scheme and a physical iPhone.
- Use debug builds for current M1 validation.
- Keep ShareSync in the foreground during transfer; background execution is not part of the M1 success promise.
- Grant local network, camera, and Photos access when prompted.

Release or beta preparation:

- Confirm bundle identifiers, display names, signing teams, and version strings before producing installable archives.
- Keep local HTTPS as a pre-release security hardening task unless a deliberate M1 scope change is made.
- Re-run the full M1 manual regression checklist on physical devices after any signing, entitlement, or network-stack change.
- Do not add contacts, files, reverse sync, videos, BLE discovery, or unattended background sync to an M1 release candidate.

## Manual Regression Checklist

Run this on physical Android and iPhone devices on the same Wi-Fi network:

- Fresh install Android and iOS debug builds.
- Android grants photo and notification permission.
- Android shows the pairing QR code without requiring manual server controls.
- iOS scans the QR code and lands on the photo sync workflow.
- iOS fetches the photo manifest from the paired Android device.
- iOS syncs at least one photo and the photo appears in iOS Photos.
- iOS syncs all currently pending photos.
- Android latest sync status updates after iOS posts the result.
- iOS latest sync status updates after import and result post.
- Reopen iOS app and confirm pairing and endpoint state restore.
- Restart Android sharing, confirm iOS can rediscover or validate the paired Android endpoint.
- Delete one imported photo from iOS Photos, reopen ShareSync, and confirm it becomes retryable.
- Clear iOS local sync state and confirm imported Photos library items remain.
- Clear Android sync result state and confirm manifest counts rebuild.
- Revoke iOS Photos permission and confirm ShareSync blocks import with a clear message.
- Revoke Android photo permission and confirm Android stops sharing photos with a clear message.
- Put iOS app in background during transfer and confirm transfer pauses or fails retryably without corrupting state.
- Run `./scripts/check-m0.sh` after the device pass.

Record pass/fail notes in `docs/m0-validation-results.md` until a dedicated M1 validation result file is introduced.

## Explicit Post-M1 Branches

These are product branches after the photo-only MVP and must not block M1:

- Videos.
- Contacts.
- Files and iCloud Documents.
- BLE discovery.
- Reverse sync from iOS to Android.
- Bidirectional merge and conflict UI.
- Fully unattended iOS background sync.
- Local HTTPS certificate trust UX, if not pulled into M1 by scope change.
- App Store and Google Play commercial release work.
