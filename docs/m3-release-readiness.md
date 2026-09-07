# M3 Pre-Release Readiness

Status: Draft readiness checklist for the photo-only pre-release candidate.

M3 is not a public App Store or Google Play release. It is a pre-release hardening milestone for a single-user Android-to-iPhone photo sync workflow.

## Supported Behavior

- Android shares local Photos/MediaStore photo items to a paired iPhone.
- iPhone downloads Android photos over the local network and imports them into iOS Photos.
- iCloud Photos backup happens only after iOS Photos import, using the user's existing iCloud settings.
- Transfer uses the local network only; ShareSync does not use a cloud relay.
- iOS sync is foreground-driven. If the iOS app leaves the foreground, active transfer is paused/cancelled and can be resumed.
- Pairing survives ordinary Android/iOS app restarts.
- Endpoint changes can be recovered by paired-device discovery or clear recovery messaging.
- Imported photo mappings are stored locally to prevent repeat imports during normal app usage.
- Deleted imported iOS Photos assets can be detected and made retryable.
- Android receives iOS sync results and keeps recent result/event history for validation.

## Known Limitations

- Deleting the iOS app deletes ShareSync's local import mapping; after reinstall, previously imported Android photos may sync again.
- M3 does not promise unattended iOS background sync.
- M3 does not sync videos, contacts, files, iCloud Drive documents, or app data.
- M3 does not perform destructive delete sync.
- M3 does not directly access iCloud, Apple ID, or iCloud credentials.
- M3 still uses signed local HTTP until the dedicated local HTTPS implementation is completed.
- Network discovery depends on local network conditions and may require QR refresh or endpoint recovery when mDNS is unavailable.

## Release Gates

Before calling M3 ready:

- `./scripts/check-m0.sh` passes.
- M2 physical-device validation results are filled in.
- Error and recovery copy is consistent across Android and iOS.
- Recent sync history is available without copying raw JSON.
- Reset and clear-pairing behavior is documented and does not surprise users.
- Local HTTPS implementation is either completed or explicitly scoped to the next pre-release security milestone.
- No private identity, generated build output, or local-only machine artifacts are committed.

## Validation Documents

- [M0 Device Validation Checklist](m0-device-validation.md)
- [M0 Validation Results](m0-validation-results.md)
- [M1 Release Readiness](m1-release-readiness.md)
- [M2 Device Validation Results](m2-device-validation-results.md)
- [M2 iOS Foreground/Background Checklist](m2-ios-foreground-background-checklist.md)
- [Local HTTPS Threat Model](local-https-threat-model.md)

## Signoff Notes

M3 should be evaluated as a reliable photo bridge, not as a complete cross-platform sync suite. Product branches such as videos, contacts, files, reverse sync, and unattended background sync should be planned after the photo MVP is stable enough to test repeatedly.
