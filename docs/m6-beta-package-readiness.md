# M6 Beta Package Readiness

Status: Active beta-package readiness guidance for the photo-only MVP.

M6 prepares ShareSync for safer internal beta handoff. It does not expand the MVP scope and does not replace real-device validation.

## Scope Boundary

The beta package remains limited to Android-to-iOS photo transfer on the local network:

- Android is the photo source and sync controller.
- iPhone receives photos and imports them into Photos.
- iCloud backup happens only through Apple's normal iCloud Photos pipeline after import.
- ShareSync does not access Apple ID, iCloud credentials, iCloud Drive, or iCloud private APIs.
- ShareSync does not use a cloud relay or third-party storage.
- iOS must stay foregrounded for active transfer.
- Videos, contacts, files, reverse sync, delete propagation, and unattended iOS background sync remain out of scope.

## Version Alignment Policy

Every paired Android/iOS beta handoff must use matching user-visible versions:

- Android `versionName` must match iOS `MARKETING_VERSION`.
- Android `versionCode` must match iOS `CURRENT_PROJECT_VERSION` for paired internal artifacts.
- Build numbers must increase monotonically for every distributed internal beta package.
- Copied diagnostics must include app version/build so support notes can identify the exact artifact.

The release-readiness gate checks the current Android and iOS version values and fails when they diverge.

## Internal Beta Artifact Notes

Record these details with every internal artifact:

- Git commit SHA.
- Android version name/code.
- iOS marketing version/build.
- Transport mode: `signed-http` or `qr-pinned-https`.
- Validation status: automated checks, deferred real-device checks, and known limitations.

Transport expectations:

- `signed-http` is the current internal local-network validation transport.
- `qr-pinned-https` is opt-in and must not be treated as release-ready until M4 physical-device security validation is completed and recorded.
- Do not distribute builds that require local development signing files, generated output, DerivedData, local SDK paths, secrets, or credentials from the repository.

## Permission And Privacy Copy Checklist

Use this checklist when changing permission strings, store copy, onboarding copy, or support text:

- Say the app transfers photos locally between the paired Android phone and iPhone.
- Say the iPhone imports received photos into Photos.
- Say iCloud backup depends on the user's existing iCloud Photos settings.
- Say there is no ShareSync cloud relay.
- Say ShareSync does not access Apple ID, iCloud credentials, or iCloud Drive.
- Say iOS transfer requires the app to remain open and foregrounded.
- Do not imply unattended iOS background sync.
- Do not imply videos, contacts, files, reverse sync, or delete propagation are supported.
- Do not imply imported photos are removed from Android.

Current permission wording is aligned with the photo-only local-sync claim:

- iOS camera: scan the Android pairing code.
- iOS local network: connect to the paired Android phone on the local network.
- iOS Photos add/read: import Android photos and create/use the ShareSync backup album.
- Android media read: read Android photos for the manifest and transfer endpoint.
- Android foreground service/notification: keep the local photo transfer endpoint available while ShareSync is open or backgrounded.

## Release-Readiness Gate

Run the signed local HTTP gate before treating a build as internally handoff-ready:

```sh
bash scripts/check-release-readiness.sh --transport signed-http
```

Run the QR-pinned HTTPS gate only when validating that transport:

```sh
bash scripts/check-release-readiness.sh --transport qr-pinned-https
```

The QR-pinned HTTPS gate is expected to fail until M4 physical-device security validation is completed and recorded.

Generate a beta handoff record before sharing internal artifacts:

```sh
bash scripts/generate-beta-handoff.sh --transport signed-http
```

Use `--output` to write the record outside the repository alongside manually produced APK/IPA artifacts.

Generate a beta handoff record before sharing internal artifacts:

```sh
bash scripts/generate-beta-handoff.sh --transport signed-http
```

Use `--output` to write the record outside the repository alongside manually produced APK/IPA artifacts.
