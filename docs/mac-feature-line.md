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
- One-time, challenge-bound AES-256-GCM encrypted Android pairing callback accepted only while the Mac pairing sheet is open.
- Private-LAN socket callback avoids enabling unrestricted Android cleartext HTTP traffic.
- Manual Android payload import retained only as a development fallback.
- Durable trusted-device binding in Application Support.
- Android pairing secret persistence across photo-service and app restarts.
- Bonjour endpoint rediscovery, with the saved host and port as fallback.
- Automatic endpoint rediscovery on Mac launch, refresh, and transfer so Android IP changes do not require re-pairing.
- Visible Mac-side unpair action that removes connection credentials while retaining imported-photo history.
- Android health identity validation before protected requests.
- Automatic Android health validation and photo-manifest refresh immediately after pairing.
- Signed manifest, media, and sync-result requests.
- Paged photo manifest loading.
- Single-photo and sync-all transfer with per-photo size and optional SHA-256 validation.
- Sequential download/import pipeline with visible progress, cancellation, retry, and restart resume.
- PhotoKit import into the `ShareSync Backup` album.
- Persistent duplicate-prevention state and stable Mac target identity.
- Automatic retry of locally stored completion results when the manifest is refreshed.
- App Sandbox access limited to outbound networking and Photos.

The original one-photo validation action remains available, while the primary action now synchronizes all pending photos through the same resumable transfer core used by iOS.

## M1 progress

Implemented:

- Sync-all with sequential transfer, visible progress, cancellation boundaries, and restart resume.
- Persistent recent-sync history restored when the app launches.
- Visible Android completion-return status, diagnostic code, and manual retry action.
- Automatic completion-return retries during later manifest refreshes and transfers.
- Photos deletion reconciliation; an imported Android photo that is removed from Photos becomes eligible for sync again.
- Menu-bar status with open, sync-now, settings, and quit actions.
- A keep-running preference that controls whether closing the last window terminates ShareSync.
- Optional 5, 15, 30, or 60 minute scheduled sync while ShareSync is running and the Mac is awake.
- A per-scheduled-run limit of 25, 50, 100, or all remaining photos.

Automatic sync is off by default. Enabling it does not register a login item or claim execution while the app is quit, the user is logged out, or the Mac is asleep.

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

- Implemented: menu-bar status, keep-running preference, sync-all, bounded scheduled batches, awake-session scheduling, interrupted-download resume, Photos deletion reconciliation, completion-return retry state, and diagnostics.

### Mac M2: gateway ownership (complete)

- Implemented: Android registers Apple clients, selects one active iCloud backup device, exposes the selection in Settings, and rejects inactive manifest requests with `SS-GATEWAY-409`.
- Implemented: completion state is persisted per target device, manifests are filtered for the requesting gateway, and signed completion reports must match the requesting device ID.
- Implemented: registered iPhone and Mac gateways share one iCloud Photos completion boundary while retaining per-device result history; successful imports are not re-offered after handoff, while failures remain retryable.
- Implemented: failed and conflicted items remain retryable across handoff; resetting history clears the shared iCloud completion boundary and event log while preserving pairing and active-gateway ownership.

### Mac M3: pairing hardening

- Implemented: signed-request protocol v2 binds protocol version, device ID, and session ID into the HMAC payload so gateway identity cannot be replaced after signing.
- Implemented: Mac pairing offer v2 carries a one-time 256-bit key in the QR trust channel; Android encrypts the callback payload with AES-GCM and binds it to the pairing challenge before sending it over the private LAN.
- Implemented: each Mac pairing rotates a device-scoped request-signing secret; pending and active credentials overlap only for the callback handoff, and registered or revoked devices cannot fall back to the legacy bootstrap secret.
- Implemented: Android can remove a credential-managed Mac, revoke its signing secret, and select the most recently seen remaining iCloud gateway when the removed Mac was active.
- Implemented: iOS scans a short-lived registration credential from Android QR, registers its persistent device identity, and stores only the returned device-scoped signing secret before automatic sync begins.
- Implemented: iPhone and Mac can sign a best-effort remote unpair request that revokes their Android credential and gateway registration before local pairing data is cleared; Android settings remain the offline fallback.
- Implemented: the Mac pairing sheet discovers nearby Android advertisements and presents their readable names as untrusted hints; QR scan and encrypted callback remain the only trust path.
- Add device-management presentation for revoked, stale, and recently active gateways.

### Mac M4: distribution readiness

- Add a Mac app icon and signed Release/Beta channels.
- Add unit and UI test targets for Mac presentation and orchestration.
- Complete privacy manifest, accessibility, localization, notarization, and beta packaging checks.
