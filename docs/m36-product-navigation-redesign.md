# M36 Product Navigation Redesign

Status: Complete static checkpoint.

M36 replaces the long diagnostic-first screens with task-focused product navigation while preserving the existing photo transfer behavior.

## Product Decisions

- The home screen answers three questions: current state, what happens next, and what the user can do now.
- Only one primary action is emphasized at a time.
- History and support information no longer compete with the sync task.
- Technical connection fields remain available, but live under settings and support.
- Android and iOS share the same information architecture while retaining native controls and terminology.

## Android

- `Sync` contains readiness, the current action, and the pairing QR code.
- `Activity` contains recent sync outcomes and transfer details.
- `Settings` contains privacy, connection, and support tools.
- Permission, start, and stop controls are mutually revealed according to runtime state.
- The selected section survives Activity recreation.

## iOS

- `Receive` contains connection state, photo summary, and the primary receive action.
- `Activity` contains detailed photo and transfer history.
- `Settings` contains auto-sync preference, privacy, and advanced support controls.
- The stop action appears only while a transfer can actually be stopped.
- Successful pairing returns the user to Receive.

## Validation

Run:

```bash
bash scripts/check-ui-quality.sh
```

The gate verifies bilingual navigation resources and the three-section structure on both platforms. Physical-device visual review remains deferred.
