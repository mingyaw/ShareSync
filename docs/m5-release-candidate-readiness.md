# M5 Release Candidate Readiness

Status: M5 release-candidate polish baseline.

M5 keeps ShareSync scoped to a single-user, photo-only Android-to-iPhone local sync workflow. It is a release-candidate preparation milestone, not a public App Store or Google Play release.

## Supported Main Axis

- Android shares local photos to a paired iPhone over the local network.
- iOS imports received photos into Photos so iCloud Photos can back them up after import.
- iOS keeps paired Android device metadata so unchanged pairings do not require scanning a QR code before every sync.
- iOS can resume interrupted photo transfers using persisted local transfer state.
- Android receives signed sync results from iOS and keeps recent local sync history.
- Both platforms provide redacted diagnostics copy for validation and support notes.

## Explicit Limitations

- iOS does not provide unattended background sync.
- Videos, contacts, files, app data, and reverse sync are product branches after the photo MVP.
- Delete propagation is not supported.
- ShareSync does not access iCloud, Apple ID, iCloud credentials, or iCloud Drive directly.
- No cloud relay or third-party storage is introduced.
- QR-pinned HTTPS is implemented behind an opt-in validation build flag, but remains blocked for release readiness until physical-device validation is recorded.

## Release Gates

Required before treating the signed-HTTP developer build as release-candidate ready:

- `bash scripts/check-repo-hygiene.sh`
- `bash scripts/check-release-readiness.sh --transport signed-http`
- `./scripts/check-m0.sh`
- M0/M2 real-device photo validation evidence remains passing for the intended device matrix.

Required before treating QR-pinned HTTPS as release-candidate ready:

- Build Android with `-Psharesync.qrPinnedHttps=true`.
- Complete and record `M4-SEC-001`, `M4-SEC-002`, and `M4-SEC-003` in `m2-device-validation-results.md`.
- `bash scripts/check-release-readiness.sh --transport qr-pinned-https` passes.
- Run the full M0 physical-device photo flow over QR-pinned HTTPS.

## Pairing And IP Recovery Contract

Pairing binds the iPhone to the Android device identity and pairing secret, not to a permanent IP address.

Expected behavior:

- If the Android IP changes but discovery finds the same device identity, iOS updates the endpoint and continues.
- If discovery fails but the stored endpoint is still reachable and health validation matches the paired device, iOS continues.
- If the endpoint belongs to a different Android device, iOS rejects it and asks for a fresh QR code.
- If QR-pinned HTTPS is active and the certificate fingerprint changes, iOS must reject the connection and require clearing pairing plus scanning a fresh QR code.

## Diagnostics Policy

Copied diagnostics may include:

- app/platform state,
- endpoint and transport mode,
- permission status,
- photo counts,
- transfer state,
- recent request status,
- sync batch ids and aggregate counts.

Copied diagnostics must not include:

- pairing payload JSON,
- pairing tokens,
- request signatures,
- shared secrets,
- private keys,
- certificate private-key material.

## Current Signoff

M5 is ready for continued local development once automated checks pass. Real-device validation is intentionally deferred by current scope, and QR-pinned HTTPS remains non-release-ready until the explicit M4 security matrix is completed.
