# M14 Support Snapshot Strict Next-Step Validation

Status: Complete strict next-step validation for support snapshot triage.

M14 tightens the support snapshot inspector so beta triage rejects invalid or cross-platform next-step values.

## Validation Behavior

The support snapshot inspector now checks:

- `nextStep` exists.
- `nextStep` is a non-empty string.
- Android snapshots only use Android next-step action codes.
- iOS snapshots only use iOS next-step action codes.

This keeps copied diagnostics machine-readable and prevents support notes from mixing Android and iOS action states.

## Android Next Steps

- `allow_android_photos`
- `start_android_sharing`
- `wait_for_android_server`
- `scan_from_iphone`
- `wait_for_retry_resume`
- `wait_for_new_android_photos`

## iOS Next Steps

- `scan_android_qr`
- `review_android_endpoint`
- `allow_iphone_photos`
- `keep_sharesync_open`
- `fetch_latest_manifest`
- `sync_remaining_photos`

## Scope Reminder

M14 remains limited to the photo-only MVP:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only.
- No cloud relay.
- No direct iCloud API.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
- Real-device validation remains deferred until explicitly resumed.
