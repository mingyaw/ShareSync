# M13 Support Next-Step Snapshot

Status: Complete support snapshot extension for the photo-only MVP.

M13 extends the support snapshot contract so copied diagnostics include both the current phase and the next actionable step.

## Snapshot Fields

Support snapshots now include:

- `phase`: current user-facing state.
- `nextStep`: machine-readable next user action.

The `nextStep` field is intentionally not localized. Support tooling and beta notes can rely on stable values even when the app is running in Traditional Chinese or English.

## Android Values

Android can report:

- `allow_android_photos`
- `start_android_sharing`
- `wait_for_android_server`
- `scan_from_iphone`
- `wait_for_retry_resume`
- `wait_for_new_android_photos`

## iOS Values

iOS can report:

- `scan_android_qr`
- `review_android_endpoint`
- `allow_iphone_photos`
- `keep_sharesync_open`
- `fetch_latest_manifest`
- `sync_remaining_photos`

## Support Workflow

When a beta tester copies diagnostics:

- Use `phase` to understand where the app is now.
- Use `nextStep` to understand the action the app is asking for.
- Use platform-specific fields to diagnose local network, permission, manifest, or transfer state.

## Scope Reminder

M13 remains limited to the photo-only MVP:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only.
- No cloud relay.
- No direct iCloud API.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
- Real-device validation remains deferred until explicitly resumed.
