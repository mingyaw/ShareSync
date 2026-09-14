# M12 Readiness Presenter Hardening

Status: Complete tested readiness presenter hardening for the photo-only MVP.

M12 keeps M11's product-focused first screen, but moves the next-step decision into platform readiness models so UI rendering, button behavior, and automated tests all follow the same state.

## Why This Matters

The beta flow depends on clear operator guidance:

- Android should tell the user whether to allow Photos, make photos available, wait, scan from iPhone, keep the screen open for retry, or wait for new photos.
- iOS should tell the user whether to scan Android, review the connection, allow Photos, keep the app open, fetch the latest list, or sync remaining photos.

These decisions should not live only in view code because that makes regressions hard to catch without real devices.

## Implementation

### Android

`AndroidPhotoSyncReadiness` now exposes `nextStep`, derived from the existing primary action.

The Android activity maps `nextStep` to localized product copy. The runtime model remains the source of truth for the next-step state.

### iOS

`PhotoSyncReadiness` now exposes `nextStep`, derived from the existing primary action.

The SwiftUI receive screen maps `nextStep` to localized product copy and iconography. The readiness model remains the source of truth for the next-step state.

## Automated Coverage

Android readiness tests now assert next-step values for:

- Photo permission required.
- Server stopped.
- Pairing QR ready.
- Retry required.
- Transfer complete.

iOS readiness tests now assert next-step values for:

- Pairing required.
- Invalid endpoint.
- Photos permission blocked.
- Active transfer.
- Ready to fetch.
- Ready to sync.

## Scope Reminder

M12 remains limited to the photo-only MVP:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only.
- No cloud relay.
- No direct iCloud API.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
- Real-device validation remains deferred until explicitly resumed.
