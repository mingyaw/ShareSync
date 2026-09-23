# ShareSync macOS Feature Line

## Product role

The Mac app is an alternate local Photos gateway for an Android-first owner. It reuses the same direct local-network protocol as iOS, imports through PhotoKit, and lets the system Photos library perform normal iCloud Photos synchronization. ShareSync does not write into the Photos library bundle and does not introduce a cloud relay.

The Mac line improves availability because a signed-in desktop app can remain open for long periods. It does not claim unrestricted execution after the user quits the app, logs out, or the Mac sleeps.

## M0 implementation

Open `macos/ShareSyncMac.xcodeproj` and run the `ShareSyncMac` scheme.

M0 includes:

- Native SwiftUI window designed for desktop use.
- Traditional Chinese and English UI.
- Mac-generated, three-minute pairing QR scanned by Android.
- Android in-app live camera scanner that completes pairing without taking a photo.
- One-time, challenge-protected Android pairing callback accepted only while the Mac pairing sheet is open.
- Private-LAN socket callback avoids enabling unrestricted Android cleartext HTTP traffic.
- Manual Android payload import retained only as a development fallback.
- Durable trusted-device binding in Application Support.
- Android pairing secret persistence across photo-service and app restarts.
- Bonjour endpoint rediscovery, with the saved host and port as fallback.
- Android health identity validation before protected requests.
- Automatic Android health validation and photo-manifest refresh immediately after pairing.
- Signed manifest, media, and sync-result requests.
- Paged photo manifest loading.
- One-photo transfer with size and optional SHA-256 validation.
- PhotoKit import into the `ShareSync Backup` album.
- Persistent duplicate-prevention state and stable Mac target identity.
- Automatic retry of locally stored completion results when the manifest is refreshed.
- App Sandbox access limited to outbound networking and Photos.

M0 deliberately transfers one photo per action. This keeps the first Mac validation small and exercises the same resumable transfer core already used by iOS.

## Shared-code boundary

The macOS target compiles the 18 files under `ios/ShareSync` directly. These files are platform-neutral or use Apple frameworks available on both iOS and macOS:

- pairing payload parser and trusted-device session
- Bonjour discovery and endpoint resolution
- request signing and certificate fingerprint validation
- manifest, media download, resume, and storage checks
- PhotoKit importer
- sync-result model, persistence, and return client

The following remain platform-specific:

- SwiftUI application shell and navigation
- presentation state and localized copy
- iOS camera QR scanner
- lifecycle and foreground/background orchestration

This arrangement avoids duplicating protocol behavior in M0. A later milestone should move the shared sources into an explicit framework target after the Mac workflow has stabilized.

## Current operating rule

Use either iPhone or Mac as the active gateway for one Android library during M0, not both concurrently. Android completion storage currently merges photo completion globally by source item. Until gateway-group semantics are added, two active gateways could cause one destination to hide a photo that only the other destination imported.

Changing the Android IP address does not require re-pairing. The saved device ID remains the trust anchor, Bonjour refreshes the endpoint, and the health response must match that device ID.

Deleting the Mac app does not necessarily remove Application Support state. A user who resets local photo history can receive previously completed items again after Android completion state is also reset. Product-facing reset flows must continue to explain this consequence.

## Verification

Build without signing:

```sh
xcodebuild \
  -project macos/ShareSyncMac.xcodeproj \
  -scheme ShareSyncMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/ShareSyncMacDerived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the shared Swift core regression suite:

```sh
swift test
```

Physical validation is intentionally deferred. The first device pass should verify pairing persistence, IP change recovery, local-network permission, Photos permission, album creation, single-photo import, completion return, retry after Android becomes unavailable, and iCloud Photos appearance on a second Apple device.

## Roadmap

### Mac M1: reliable unattended session

- Add menu-bar status and a keep-running preference.
- Add sync-all and bounded batch controls.
- Schedule refreshes while the app is running and the Mac is awake.
- Reconcile Photos deletion and interrupted downloads.
- Add visible completion-return retry state and diagnostics.

### Mac M2: gateway ownership

- Add an Android-side active-gateway selection.
- Scope completion state by gateway or gateway group.
- Define handoff between iPhone and Mac without duplicate imports.
- Add conflict and reset semantics to the shared protocol.

### Mac M3: pairing hardening

- Encrypt the one-time callback payload or move the bootstrap callback to pinned TLS.
- Add nearby-device discovery before pairing without treating discovery as trust.
- Add device management and revoked-key handling.

### Mac M4: distribution readiness

- Add a Mac app icon and signed Release/Beta channels.
- Add unit and UI test targets for Mac presentation and orchestration.
- Complete privacy manifest, accessibility, localization, notarization, and beta packaging checks.
